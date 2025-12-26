import Foundation
import CryptoKit

struct AnonIdentity: Codable {
    let profileId: Int
    let handle: String
    let cert: String
    let certKid: String
    let certExpiresAt: Date

    var isExpired: Bool {
        Date() >= certExpiresAt.addingTimeInterval(-300)
    }
}

final class AnonIdentityStore {
    private let identityKey = "looped.anon.identity"
    private let privateKeyKey = "looped.anon.privateKey"
    private let keychain = KeychainStore()

    func loadIdentity() -> AnonIdentity? {
        guard let data = keychain.load(key: identityKey) else { return nil }
        return try? JSONDecoder().decode(AnonIdentity.self, from: data)
    }

    func saveIdentity(_ identity: AnonIdentity) {
        guard let data = try? JSONEncoder().encode(identity) else { return }
        keychain.save(key: identityKey, data: data)
    }

    func clearIdentity() {
        keychain.delete(key: identityKey)
    }

    func loadPrivateKey() -> Curve25519.Signing.PrivateKey? {
        guard let data = keychain.load(key: privateKeyKey) else { return nil }
        return try? Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    func savePrivateKey(_ privateKey: Curve25519.Signing.PrivateKey) {
        keychain.save(key: privateKeyKey, data: privateKey.rawRepresentation)
    }

    func clearPrivateKey() {
        keychain.delete(key: privateKeyKey)
    }

    func clearAll() {
        clearIdentity()
        clearPrivateKey()
    }
}
