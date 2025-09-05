import Foundation
import Security

class TokenStorage {
    private let tokenKey = "looped.auth.token"
    private let refreshTokenKey = "looped.auth.refreshToken"
    
    var token: String? {
        get { getFromKeychain(key: tokenKey) }
        set { 
            if let token = newValue {
                saveToKeychain(key: tokenKey, value: token)
            } else {
                deleteFromKeychain(key: tokenKey)
            }
        }
    }
    
    var refreshToken: String? {
        get { getFromKeychain(key: refreshTokenKey) }
        set {
            if let token = newValue {
                saveToKeychain(key: refreshTokenKey, value: token)
            } else {
                deleteFromKeychain(key: refreshTokenKey)
            }
        }
    }
    
    func store(token: String, refreshToken: String) {
        self.token = token
        self.refreshToken = refreshToken
    }
    
    func clear() {
        token = nil
        refreshToken = nil
    }
    
    func hasValidToken() -> Bool {
        return token != nil
    }
    
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
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
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}