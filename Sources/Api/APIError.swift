import Foundation

/// User-facing (Polish) error type for every Librus interaction.
enum APIError: LocalizedError, Equatable {
    case network(String)
    case emptyResponse
    case decoding(String)
    case invalidCredentials
    case captchaNeeded
    case tokenExpired
    case accessDenied(String?)
    case maintenance
    case notFound
    case server(code: Int, body: String?)
    case librus(code: String, message: String?)
    case messageBridgeFailed(String)

    var errorDescription: String? {
        switch self {
        case .network(let d):
            return "Problem z połączeniem: \(d)"
        case .emptyResponse:
            return "Serwer Librusa zwrócił pustą odpowiedź."
        case .decoding(let d):
            return "Nie udało się odczytać danych z Librusa (\(d))."
        case .invalidCredentials:
            return "Portal Librus odrzucił dane logowania. Aplikacja (tak jak oficjalna appka "
                + "Librus) wymaga KONTA LIBRUS — e-mail + hasło założone na konto.librus.pl i "
                + "połączone z Twoją Synergią. Sam login szkolny (np. 1234567u) tu nie zadziała."
        case .captchaNeeded:
            return "Librus poprosił o captchę. Zaloguj się raz przez przeglądarkę na "
                + "portal.librus.pl, a potem spróbuj ponownie w aplikacji."
        case .tokenExpired:
            return "Sesja wygasła — zaloguj się ponownie."
        case .accessDenied(let what):
            if let what, !what.isEmpty { return "Brak dostępu: \(what)." }
            return "Librus odmówił dostępu do tych danych."
        case .maintenance:
            return "Trwa przerwa techniczna w Librusie. Spróbuj później."
        case .notFound:
            return "Nie znaleziono danych."
        case .server(let code, let body):
            return "Błąd serwera Librusa (\(code)). \(body ?? "")"
        case .librus(let code, let message):
            return message ?? "Błąd Librusa: \(code)"
        case .messageBridgeFailed(let d):
            return "Nie udało się zalogować do skrzynki wiadomości (\(d))."
        }
    }

    /// Maps the `error` string in a failed `OAuth/Token` response.
    static func fromTokenError(_ error: String) -> APIError {
        switch error {
        case "librus_captcha_needed": return .captchaNeeded
        case "invalid_grant": return .invalidCredentials
        case "invalid_client": return .librus(code: error, message: "Nieprawidłowy klient OAuth.")
        case "connection_problems": return .network("connection_problems")
        default: return .librus(code: error, message: nil)
        }
    }

    /// Maps the `Code` field in a failed `2.0/*` response.
    static func fromAPICode(_ code: String, message: String?) -> APIError {
        switch code {
        case "TokenIsExpired": return .tokenExpired
        case "Request is denied", "AccessDeny": return .accessDenied(message)
        case "Resource not found", "NotFound": return .notFound
        case "LuckyNumberIsNotActive": return .accessDenied("szczęśliwy numerek nie jest aktywny")
        case "Maintenance": return .maintenance
        default: return .librus(code: code, message: message)
        }
    }
}
