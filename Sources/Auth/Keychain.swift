import Foundation
import Security

/// Minimal wrapper around the iOS keychain for a single service.
/// Stores small `Data` blobs keyed by string. Used for the Librus session
/// (login, password, tokens) so nothing sensitive touches `UserDefaults`.
enum Keychain {
    private static let service = "eu.mojlibrus.app.session"

    static func set(_ data: Data, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // `…ThisDeviceOnly`: the item is usable after the first unlock (so the
            // background-refresh task can reach it), but never leaves this device
            // — it is excluded from encrypted backups and iCloud Keychain. This is
            // what makes "dane wyłącznie w Keychainie tego telefonu" actually true.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert.merge(attributes) { _, new in new }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    static func get(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func setString(_ value: String, for key: String) {
        set(Data(value.utf8), for: key)
    }

    static func string(_ key: String) -> String? {
        get(key).flatMap { String(data: $0, encoding: .utf8) }
    }

    static func setJSON<T: Encodable>(_ value: T, for key: String) {
        if let data = try? JSONEncoder().encode(value) {
            set(data, for: key)
        }
    }

    static func json<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        get(key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
