import Foundation

/// Owns the Librus session: Portal OAuth tokens + the per-Synergia-account bearer
/// token, and performs authorized `api.librus.pl/2.0/*` requests.
///
/// An `actor` so token refresh is serialized.
actor LibrusSession {
    private(set) var credentials: Credentials?
    private var refreshTask: Task<Credentials, Error>?

    private let portalAuth = PortalAuth()
    private let urlSession: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["User-Agent": Librus.userAgent]
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        self.urlSession = URLSession(configuration: config)
        self.credentials = Credentials.load()
    }

    var isLoggedIn: Bool { credentials != nil }

    // MARK: - Login

    func logIn(login: String, password: String) async throws {
        let cleanLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        let portal = try await portalAuth.logIn(login: cleanLogin, password: password)
        let accounts = try await portalAuth.synergiaAccounts(portalToken: portal.accessToken)

        guard let account = pickAccount(accounts) else {
            throw APIError.librus(code: "no_accounts",
                message: "Portal nie zwrócił żadnego konta Synergia. Sprawdź, czy konto jest połączone na portal.librus.pl.")
        }
        if account.state == "requiring_an_action" {
            throw APIError.librus(code: account.state ?? "",
                message: "Konto Synergia wymaga ponownego połączenia na portal.librus.pl.")
        }

        let synergiaToken: String
        if account.accessToken.isEmpty {
            synergiaToken = try await portalAuth.freshSynergiaToken(
                login: account.login, portalToken: portal.accessToken)
        } else {
            synergiaToken = account.accessToken
        }

        let creds = Credentials(
            login: cleanLogin, password: password, portal: portal,
            synergiaLogin: account.login, synergiaToken: synergiaToken,
            synergiaExpiry: Date().timeIntervalSince1970 + 6 * 3600,
            studentName: account.studentName
        )
        creds.save()
        credentials = creds
    }

    func logOut() {
        credentials = nil
        refreshTask = nil
        Credentials.clear()
    }

    private func pickAccount(_ accounts: [SynergiaAccount]) -> SynergiaAccount? {
        accounts.first { $0.state == nil || $0.state == "active" || $0.state == "" }
            ?? accounts.first
    }

    // MARK: - Authorized requests

    func authorizedData(
        path: String, method: String = "GET", body: Data? = nil, contentType: String? = nil
    ) async throws -> Data {
        var token = try await validSynergiaToken()
        var (data, response) = try await send(
            path: path, token: token, method: method, body: body, contentType: contentType)

        if shouldRetryAfterAuth(data: data, response: response) {
            token = try await forceRefresh().synergiaToken
            (data, response) = try await send(
                path: path, token: token, method: method, body: body, contentType: contentType)
        }
        try Self.throwIfAPIError(data: data, response: response)
        return data
    }

    /// Current Synergia bearer token, refreshed on demand. Used by the messages bridge.
    func validAccessToken() async throws -> String {
        try await validSynergiaToken()
    }

    // MARK: - Token lifecycle

    private func validSynergiaToken() async throws -> String {
        guard let creds = credentials else { throw APIError.tokenExpired }
        if creds.isSynergiaTokenValid { return creds.synergiaToken }
        return try await forceRefresh().synergiaToken
    }

    private func forceRefresh() async throws -> Credentials {
        if let refreshTask { return try await refreshTask.value }
        let task = Task<Credentials, Error> { try await performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> Credentials {
        guard var creds = credentials else { throw APIError.tokenExpired }

        // Make sure the portal token is usable, refreshing or re-logging as needed.
        if !creds.isPortalTokenValid {
            do {
                creds.portal = try await portalAuth.refresh(refreshToken: creds.portal.refreshToken)
            } catch {
                let portal = try await portalAuth.logIn(login: creds.login, password: creds.password)
                creds.portal = portal
            }
        }

        // Get a fresh Synergia bearer token for the account.
        do {
            let token = try await portalAuth.freshSynergiaToken(
                login: creds.synergiaLogin, portalToken: creds.portal.accessToken)
            creds.synergiaToken = token
            creds.synergiaExpiry = Date().timeIntervalSince1970 + 6 * 3600
        } catch {
            // Portal token might have just died — one full re-login attempt.
            let portal = try await portalAuth.logIn(login: creds.login, password: creds.password)
            creds.portal = portal
            let token = try await portalAuth.freshSynergiaToken(
                login: creds.synergiaLogin, portalToken: portal.accessToken)
            creds.synergiaToken = token
            creds.synergiaExpiry = Date().timeIntervalSince1970 + 6 * 3600
        }

        creds.save()
        credentials = creds
        return creds
    }

    // MARK: - Request plumbing

    private func send(
        path: String, token: String, method: String = "GET",
        body: Data? = nil, contentType: String? = nil
    ) async throws -> (Data, URLResponse) {
        guard let url = URL(string: "\(Librus.apiBase.absoluteString)/\(path)") else {
            throw APIError.network("zły adres: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { request.httpBody = body }
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        do {
            return try await urlSession.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func shouldRetryAfterAuth(data: Data, response: URLResponse) -> Bool {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { return true }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = obj["Code"] as? String, code == "TokenIsExpired" {
            return true
        }
        return false
    }

    private static func throwIfAPIError(data: Data, response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 503 { throw APIError.maintenance }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if status >= 400 {
                throw APIError.server(code: status, body: String(data: data, encoding: .utf8))
            }
            return
        }
        if let code = obj["Code"] as? String {
            throw APIError.fromAPICode(code, message: obj["Message"] as? String)
        }
        if status >= 400, (obj["Status"] as? String) == "Error" {
            throw APIError.server(code: status, body: obj["Message"] as? String)
        }
    }
}
