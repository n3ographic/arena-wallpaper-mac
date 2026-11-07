import Foundation
import Security
import ArenaKit

/// The Are.na token, stored as a generic password of this app.
struct KeychainSecretStore: SecretStore {
    private let service = "com.n3ographic.arenawallpaper.mac"
    private let account = "are.na-token"

    private var baseQuery: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    func token() -> String? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setToken(_ token: String) throws {
        try clearToken()
        var query = baseQuery
        query[kSecValueData] = Data(token.utf8)
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func clearToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}

struct KeychainError: Error, LocalizedError {
    let status: OSStatus
    var errorDescription: String? { String(localized: "Trousseau indisponible (\(status))") }
}
