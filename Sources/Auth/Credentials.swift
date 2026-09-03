import Foundation

/// Everything needed to talk to Librus on behalf of one Synergia account,
/// obtained through the Portal OAuth flow. Persisted as one JSON blob in the keychain.
struct Credentials: Codable, Equatable {
    /// Portal login (Synergia login like `1234567u`, or a Librus e-mail).
    var login: String
    var password: String

    var portal: PortalTokens

    /// The Synergia account chosen from the portal account list.
    var synergiaLogin: String
    var synergiaToken: String
    /// Absolute expiry of `synergiaToken` (seconds since 1970).
    var synergiaExpiry: Double
    var studentName: String?

    var isSynergiaTokenValid: Bool {
        !synergiaToken.isEmpty && Date().timeIntervalSince1970 < synergiaExpiry - 120
    }

    var isPortalTokenValid: Bool {
        !portal.accessToken.isEmpty && Date().timeIntervalSince1970 < portal.expiry - 60
    }

    static let keychainKey = "credentials.v2"

    static func load() -> Credentials? {
        Keychain.json(Credentials.self, for: keychainKey)
    }

    func save() {
        Keychain.setJSON(self, for: Credentials.keychainKey)
    }

    static func clear() {
        Keychain.delete(keychainKey)
        Keychain.delete("credentials.v1") // legacy
    }
}
