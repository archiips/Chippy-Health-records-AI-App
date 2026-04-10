import Foundation
import Security

enum KeychainKey: String {
    case accessToken  = "com.chippy.app.access_token"
    case refreshToken = "com.chippy.app.refresh_token"
    case userId       = "com.chippy.app.user_id"
    case email        = "com.chippy.app.email"
}

struct KeychainService {
    func save(token: String, forKey key: KeychainKey) {
        guard let data = token.data(using: .utf8) else { return }

        let query: [CFString: Any] = [
            kSecClass:                kSecClassGenericPassword,
            kSecAttrAccount:          key.rawValue,
            kSecValueData:            data,
            // Accessible only when device is unlocked; never migrates to other devices
            kSecAttrAccessible:       kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        SecItemDelete(query as CFDictionary)  // remove existing before inserting
        SecItemAdd(query as CFDictionary, nil)
    }

    func load(key: KeychainKey) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key.rawValue,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: KeychainKey) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
