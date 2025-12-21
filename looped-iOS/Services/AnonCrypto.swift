import Foundation
import CryptoKit
import Sodium

enum AnonCryptoError: Error, LocalizedError {
    case invalidSalt
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidPassphrase

    var errorDescription: String? {
        switch self {
        case .invalidSalt:
            return "Invalid salt"
        case .keyDerivationFailed:
            return "Unable to derive encryption key"
        case .encryptionFailed:
            return "Unable to encrypt backup"
        case .decryptionFailed:
            return "Unable to decrypt backup"
        case .invalidPassphrase:
            return "Passphrase is required"
        }
    }
}

struct AnonCrypto {
    static func randomSalt() throws -> Data {
        let sodium = Sodium()
        let length = sodium.pwHash.SaltBytes
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        guard status == errSecSuccess else { throw AnonCryptoError.invalidSalt }
        return Data(bytes)
    }

    static func deriveKey(passphrase: String, salt: Data) throws -> SymmetricKey {
        let trimmed = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AnonCryptoError.invalidPassphrase }
        let sodium = Sodium()
        guard salt.count == sodium.pwHash.SaltBytes else { throw AnonCryptoError.invalidSalt }
        let passBytes = Array(trimmed.utf8)
        let saltBytes = [UInt8](salt)
        guard let keyBytes = sodium.pwHash.hash(
            outputLength: 32,
            passwd: passBytes,
            salt: saltBytes,
            opsLimit: sodium.pwHash.OpsLimitModerate,
            memLimit: sodium.pwHash.MemLimitModerate,
            alg: .Argon2ID13
        ) else {
            throw AnonCryptoError.keyDerivationFailed
        }
        return SymmetricKey(data: Data(keyBytes))
    }

    static func encrypt(data: Data, passphrase: String, salt: Data) throws -> Data {
        let key = try deriveKey(passphrase: passphrase, salt: salt)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw AnonCryptoError.encryptionFailed
        }
        return combined
    }

    static func decrypt(data: Data, passphrase: String, salt: Data) throws -> Data {
        let key = try deriveKey(passphrase: passphrase, salt: salt)
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
