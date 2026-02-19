import Foundation
import Security

class TokenStorage {
    private let tokenKey = "looped.auth.token"
    private let refreshTokenKey = "looped.auth.refreshToken"
    private let sharedTokenKey = "looped.auth.token.shared"
    private let sharedRefreshTokenKey = "looped.auth.refreshToken.shared"
    
    var token: String? {
        get {
            if let keychainToken = getFromKeychain(key: tokenKey) {
                sharedDefaults()?.set(keychainToken, forKey: sharedTokenKey)
                return keychainToken
            }
            return sharedDefaults()?.string(forKey: sharedTokenKey)
        }
        set { 
            if let token = newValue {
                saveToKeychain(key: tokenKey, value: token)
                sharedDefaults()?.set(token, forKey: sharedTokenKey)
            } else {
                deleteFromKeychain(key: tokenKey)
                sharedDefaults()?.removeObject(forKey: sharedTokenKey)
            }
        }
    }
    
    var refreshToken: String? {
        get {
            if let keychainRefreshToken = getFromKeychain(key: refreshTokenKey) {
                sharedDefaults()?.set(keychainRefreshToken, forKey: sharedRefreshTokenKey)
                return keychainRefreshToken
            }
            return sharedDefaults()?.string(forKey: sharedRefreshTokenKey)
        }
        set {
            if let token = newValue {
                saveToKeychain(key: refreshTokenKey, value: token)
                sharedDefaults()?.set(token, forKey: sharedRefreshTokenKey)
            } else {
                deleteFromKeychain(key: refreshTokenKey)
                sharedDefaults()?.removeObject(forKey: sharedRefreshTokenKey)
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
        let data = Data(value.utf8)
        
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

    private func sharedDefaults() -> UserDefaults? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        let normalizedBundleId: String
        if bundleId.hasSuffix(".widgets") {
            normalizedBundleId = String(bundleId.dropLast(".widgets".count))
        } else {
            normalizedBundleId = bundleId
        }
        let suiteName = "group.\(normalizedBundleId)"
        return UserDefaults(suiteName: suiteName)
    }
}
