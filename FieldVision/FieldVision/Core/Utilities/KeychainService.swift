import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    
    private let service = Constants.Keychain.service
    
    private init() {}
    
    func setAccessToken(_ token: String) {
        set(token, forKey: Constants.Keychain.accessTokenKey)
    }
    
    func getAccessToken() -> String? {
        get(Constants.Keychain.accessTokenKey)
    }
    
    func setRefreshToken(_ token: String) {
        set(token, forKey: Constants.Keychain.refreshTokenKey)
    }
    
    func getRefreshToken() -> String? {
        get(Constants.Keychain.refreshTokenKey)
    }
    
    func setUserId(_ id: UUID) {
        set(id.uuidString, forKey: Constants.Keychain.userIdKey)
    }
    
    func getUserId() -> UUID? {
        guard let string = get(Constants.Keychain.userIdKey) else { return nil }
        return UUID(uuidString: string)
    }
    
    func clearAll() {
        delete(Constants.Keychain.accessTokenKey)
        delete(Constants.Keychain.refreshTokenKey)
        delete(Constants.Keychain.userIdKey)
    }
    
    private func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        delete(key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
