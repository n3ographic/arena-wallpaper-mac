import Foundation
import os
import Security
import ArenaKit

/// The Are.na token, stored as a generic password of this app.
/// Read once per launch: the app is not signed with a stable identity, so every read can ask for the Mac password.
final class KeychainSecretStore: SecretStore {
    private let cache = OSAllocatedUnfairLock<String?>(initialState: nil)
    private let service = "com.n3ographic.arenawallpaper.mac"
    private let account = "are.na-token"

    private var baseQuery: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    func token() -> String? {
        if let cached = cache.withLock({ $0 }) { return cached }
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        let value = String(data: data, encoding: .utf8)
        cache.withLock { $0 = value }
        return value
    }

    func setToken(_ token: String) throws {
        try clearToken()
        var query = baseQuery
        query[kSecValueData] = Data(token.utf8)
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        cache.withLock { $0 = token }
    }

    func clearToken() throws {
        cache.withLock { $0 = nil }
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}

struct KeychainError: Error, LocalizedError {
    let status: OSStatus
    var errorDescription: String? { String(localized: "Trousseau indisponible (\(status))") }
}
