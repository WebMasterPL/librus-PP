import Foundation

struct PortalTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiry: Double // seconds since 1970
}

struct SynergiaAccount: Decodable {
    let id: Int
    let login: String
    let accessToken: String
    let studentName: String?
    let group: String?
    let state: String?

    enum CodingKeys: String, CodingKey {
        case id, login, accessToken, studentName, group, state
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decode(Int.self, forKey: .id) { id = i }
        else { id = Int((try? c.decode(String.self, forKey: .id)) ?? "") ?? -1 }
        login = (try? c.decode(String.self, forKey: .login)) ?? ""
        accessToken = (try? c.decode(String.self, forKey: .accessToken)) ?? ""
        studentName = try? c.decode(String.self, forKey: .studentName)
        group = try? c.decode(String.self, forKey: .group)
        state = try? c.decode(String.self, forKey: .state)
    }
}

/// The Librus Portal OAuth flow: scrape + submit the login form, follow the
/// redirect chain to `app://librus?code=…`, exchange for portal tokens, then pull
/// per-Synergia-account bearer tokens.
actor PortalAuth {
    /// The session used for the current login flow (fresh cookies each time).
    private var http: URLSession = PortalAuth.makeSession()

    private static func makeSession() -> URLSession {
        // Ephemeral sessions get their own isolated in-memory cookie jar — using
        // that (rather than a hand-made HTTPCookieStorage) is what actually persists
        // the Laravel session cookie across the redirect chain.
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpShouldUsePipelining = false
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: RedirectBlocker(), delegateQueue: nil)
    }

    private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
        // Return the redirect request unchanged for http(s) hops so cookies + the
        // session flow, but stop at the `app://` hop (URLSession can't open it).
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest) async -> URLRequest? {
            if let scheme = request.url?.scheme, scheme != "http", scheme != "https" {
                return nil
            }
            if request.url?.absoluteString.contains("code=") == true {
                return nil
            }
            return request
        }
    }

    // MARK: - Public

    func logIn(login: String, password: String) async throws -> PortalTokens {
        let code = try await runLoginFlow(login: login, password: password)
        return try await exchange(body: [
            "client_id": Librus.portalClientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Librus.portalRedirectURI,
        ])
    }

    func refresh(refreshToken: String) async throws -> PortalTokens {
        try await exchange(body: [
            "client_id": Librus.portalClientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
        ])
    }

    func synergiaAccounts(portalToken: String) async throws -> [SynergiaAccount] {
        let data = try await portalGET(Librus.synergiaAccountsURL(), bearer: portalToken)
        let decoder = JSONDecoder()
        struct Wrapper: Decodable { let accounts: [SynergiaAccount]? }
        if let accounts = (try? decoder.decode(Wrapper.self, from: data))?.accounts {
            return accounts
        }
        if let accounts = try? decoder.decode([SynergiaAccount].self, from: data) {
            return accounts
        }
        let body = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
        throw APIError.librus(code: "accounts_shape", message: "Nie rozpoznano listy kont: \(body)")
    }

    func freshSynergiaToken(login: String, portalToken: String) async throws -> String {
        let data = try await portalGET(Librus.synergiaAccountFreshURL(login: login), bearer: portalToken)
        guard let account = try? JSONDecoder().decode(SynergiaAccount.self, from: data),
              !account.accessToken.isEmpty else {
            throw APIError.tokenExpired
        }
        return account.accessToken
    }

    // MARK: - Login flow

    private func runLoginFlow(login: String, password: String) async throws -> String {
        http.invalidateAndCancel()
        http = PortalAuth.makeSession() // clean cookie jar for this attempt

        // 1. Load the login page (URLSession auto-follows redirect/dru → login).
        let (pageData, pageResponse) = try await send(
            Librus.portalAuthorizeURL, method: "GET",
            headers: ["X-Requested-With": Librus.portalRequestedWith])

        if let code = codeFromLocation(pageResponse.value(forHTTPHeaderField: "Location") ?? "") {
            return code // already authenticated somehow
        }
        let loginHTML = String(data: pageData, encoding: .utf8) ?? ""
        let landed = (pageResponse.url?.absoluteString ?? "").replacingOccurrences(
            of: "https://portal.librus.pl", with: "")

        guard loginHTML.contains("konto-librus/login/action") || loginHTML.contains("id=\"login\"") else {
            throw APIError.librus(code: "portal_flow",
                message: "Nie dotarłem do formularza logowania (wylądowałem na \(landed), \(pageData.count) B).")
        }
        if loginHTML.range(of: "recaptcha|g-recaptcha|grecaptcha", options: .regularExpression) != nil {
            throw APIError.captchaNeeded
        }

        // 2. Build + submit the login form.
        let csrf = HTTP.firstMatch("name=\"csrf-token\"\\s+content=\"([^\"]+)\"", in: loginHTML)
            ?? HTTP.firstMatch("name=\"_token\"[^>]*value=\"([^\"]+)\"", in: loginHTML)
        var form = HTTP.hiddenInputs(in: loginHTML)
        form["email"] = login
        form["password"] = password
        if let csrf, form["_token"] == nil { form["_token"] = csrf }

        var headers = [
            "X-Requested-With": Librus.portalRequestedWith,
            "Referer": pageResponse.url?.absoluteString ?? "https://portal.librus.pl/konto-librus/login",
            "Origin": Librus.portalOrigin,
        ]
        if let csrf { headers["X-CSRF-TOKEN"] = csrf }

        // URLSession follows every http(s) redirect and stops at app://…code=… .
        let (postData, postResponse) = try await send(
            Librus.portalLoginActionURL, method: "POST", headers: headers, form: form)

        // The stop happens at the 302 whose Location is app://librus?code=… .
        if let code = codeFromLocation(postResponse.value(forHTTPHeaderField: "Location") ?? "") {
            return code
        }
        if let code = codeFromLocation(postResponse.url?.absoluteString ?? "") {
            return code
        }

        // No code — we landed somewhere. Figure out why.
        let finalURL = (postResponse.url?.absoluteString ?? "")
        let body = String(data: postData, encoding: .utf8) ?? ""

        if body.range(of: "recaptcha|g-recaptcha", options: .regularExpression) != nil
            || finalURL.contains("captcha") {
            throw APIError.captchaNeeded
        }
        let badCreds = ["Upewnij się, że nie", "Podany adres e-mail jest nieprawidłowy",
                        "nieprawidłowy login lub hasło", "Nieprawidłowe dane logowania",
                        "Konto zostało zablokowane"]
        if badCreds.contains(where: { body.range(of: $0, options: .caseInsensitive) != nil }) {
            throw APIError.invalidCredentials
        }
        if body.contains("Sesja logowania wygasła") || postResponse.statusCode == 419 {
            throw APIError.librus(code: "csrf", message: "Sesja portalu wygasła (CSRF). Spróbuj ponownie.")
        }
        if finalURL.contains("/konto-librus/login") {
            throw APIError.invalidCredentials
        }
        // Something else entirely — hand over the details.
        let snippet = body.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ").prefix(160)
        throw APIError.librus(code: "portal_flow",
            message: "Logowanie nie dało kodu. URL: \(finalURL.replacingOccurrences(of: "https://portal.librus.pl", with: "")) "
                + "[\(postResponse.statusCode)], \(postData.count) B. \(snippet)")
    }

    // MARK: - Token exchange

    private func exchange(body: [String: String]) async throws -> PortalTokens {
        var request = URLRequest(url: URL(string: Librus.portalTokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Librus.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = HTTP.formBody(body)

        let (data, response) = try await dataOrThrow(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.server(code: status, body: String(data: data, encoding: .utf8))
        }
        if status != 200 || obj["access_token"] == nil {
            let hint = (obj["hint"] as? String) ?? (obj["error"] as? String) ?? (obj["message"] as? String)
            if hint == "unsupported_grant_type" || hint == "invalid_grant" {
                throw APIError.tokenExpired
            }
            throw APIError.librus(code: hint ?? "portal_token", message: hint)
        }
        let expiresIn = (obj["expires_in"] as? Double) ?? Double(obj["expires_in"] as? Int ?? 3600)
        return PortalTokens(
            accessToken: obj["access_token"] as? String ?? "",
            refreshToken: (obj["refresh_token"] as? String) ?? "",
            expiry: Date().timeIntervalSince1970 + expiresIn
        )
    }

    // MARK: - Low level

    private func portalGET(_ urlString: String, bearer: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw APIError.network("zły adres portalu") }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Librus.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await dataOrThrow(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.tokenExpired }
        if status != 200 {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let reason = (obj["reason"] as? String) ?? (obj["message"] as? String) ?? (obj["hint"] as? String)
                if reason == "Access token is invalid" { throw APIError.tokenExpired }
                throw APIError.librus(code: reason ?? "portal_api", message: reason)
            }
            throw APIError.server(code: status, body: String(data: data, encoding: .utf8))
        }
        return data
    }

    private func send(
        _ urlString: String, method: String,
        headers: [String: String] = [:], form: [String: String]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: urlString) else { throw APIError.network("zły adres: \(urlString)") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(Librus.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/json", forHTTPHeaderField: "Accept")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        if let form {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = HTTP.formBody(form)
        }
        let (data, response) = try await dataOrThrow(request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("brak odpowiedzi HTTP")
        }
        return (data, http)
    }

    private func dataOrThrow(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await http.data(for: request) }
        catch { throw APIError.network(error.localizedDescription) }
    }

    private func codeFromLocation(_ location: String) -> String? {
        guard location.contains(Librus.portalRedirectURI) || location.contains("code=") else { return nil }
        if let comps = URLComponents(string: location),
           let code = comps.queryItems?.first(where: { $0.name == "code" })?.value {
            return code
        }
        return HTTP.firstMatch("[?&]code=([^&\\s]+)", in: location)
    }
}
