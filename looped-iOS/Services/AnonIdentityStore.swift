import Foundation
import CryptoKit

struct AnonCommunityMembership: Codable {
    let cert: String
    let certKid: String
    let certExpiresAt: Date

    var isExpired: Bool {
        Date() >= certExpiresAt.addingTimeInterval(-300)
    }
}

struct AnonIdentity: Codable {
    let profileId: Int
    let handle: String
    let memberships: [Int: AnonCommunityMembership]

    func membership(for communityId: Int) -> AnonCommunityMembership? {
        memberships[communityId]
    }
}

private struct LegacyAnonIdentity: Codable {
    let profileId: Int
    let handle: String
    let cert: String
    let certKid: String
    let certExpiresAt: Date
}

final class AnonIdentityStore {
    private let identityKey = "looped.anon.identity"
    private let privateKeyKey = "looped.anon.privateKey"
    private let keychain = KeychainStore()

    func loadIdentity() -> AnonIdentity? {
        guard let data = keychain.load(key: identityKey) else { return nil }
        let decoder = JSONDecoder()
        if let identity = try? decoder.decode(AnonIdentity.self, from: data) {
            return identity
        }
        if let legacy = try? decoder.decode(LegacyAnonIdentity.self, from: data) {
            guard let communityId = resolveMigrationCommunityId() else { return nil }
            let membership = AnonCommunityMembership(
                cert: legacy.cert,
                certKid: legacy.certKid,
                certExpiresAt: legacy.certExpiresAt
            )
            let identity = AnonIdentity(
                profileId: legacy.profileId,
                handle: legacy.handle,
                memberships: [communityId: membership]
            )
            saveIdentity(identity)
            return identity
        }
        return nil
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

    private func resolveMigrationCommunityId() -> Int? {
        let lastPosted = UserDefaults.standard.integer(forKey: "lastPostedCommunityId")
        if lastPosted > 0 {
            return lastPosted
        }
        let lastSelected = UserDefaults.standard.integer(forKey: "lastSelectedCommunityId")
        if lastSelected > 0 {
            return lastSelected
        }
        return nil
    }
}
