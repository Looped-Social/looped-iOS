import Foundation
import CryptoKit
import Security

enum AppleSignInUtilities {
    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        if status == errSecSuccess {
            var result = ""
            result.reserveCapacity(length)
            for byte in bytes {
                result.append(charset[Int(byte) % charset.count])
            }
            return result
        }

        #if DEBUG
        print("SecRandomCopyBytes failed (OSStatus \(status)); using UUID-based nonce fallback.")
        #endif

        var result = ""
        result.reserveCapacity(length)
        var remaining = length
        while remaining > 0 {
            for byte in UUID().uuidString.utf8 {
                result.append(charset[Int(byte) % charset.count])
                remaining -= 1
                if remaining == 0 { break }
            }
        }
        return result
    }
}

