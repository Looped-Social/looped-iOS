import Foundation
import CryptoKit

struct AnonPostContext {
    let profileId: Int
    let cert: String
    let certKid: String
    let signature: String
    let timestamp: Int
}

struct AnonActionContext {
    let profileId: Int
    let cert: String
    let certKid: String
    let signature: String
}

enum AnonAction {
    case like(postId: Int)
    case save(postId: Int)
    case unsave(postId: Int)
    case comment(postId: Int)
    case commentLike(commentId: Int)
    case commentList(postId: Int)
    case commentReplies(commentId: Int)
    case commentUserReplies(userId: Int)
}

enum AnonServiceError: Error, LocalizedError {
    case missingIdentity
    case missingCommunityContext

    var errorDescription: String? {
        switch self {
        case .missingIdentity:
            return "No anonymous identity found on this device."
        case .missingCommunityContext:
            return "Select a community before enabling anonymous mode."
        }
    }
}

actor AnonService {
    static let shared = AnonService()

    nonisolated var isAnonymousEnabled: Bool {
        UserDefaults.standard.bool(forKey: "anonymousMode")
    }

    private let anonHeaders = ["X-Actor": "anon"]
    private let lastPostedCommunityKey = "lastPostedCommunityId"
    private let lastSelectedCommunityKey = "lastSelectedCommunityId"
    private let apiClient: APIClient
    private let store: AnonIdentityStore
    private let signer: RSABlindSigner
    private let backupStore: AnonBackupStore

    init(
        apiClient: APIClient = APIClient(),
        store: AnonIdentityStore = AnonIdentityStore(),
        signer: RSABlindSigner = RSABlindSigner(),
        backupStore: AnonBackupStore = AnonBackupStore()
    ) {
        self.apiClient = apiClient
        self.store = store
        self.signer = signer
        self.backupStore = backupStore
    }

    func currentIdentity() -> AnonIdentity? {
        store.loadIdentity()
    }

    func ensureIdentity(communityId: Int? = nil) async throws -> AnonIdentity {
        if let identity = store.loadIdentity(), !identity.isExpired, store.loadPrivateKey() != nil {
            return identity
        }
        guard let resolvedCommunityId = resolveCommunityId(explicit: communityId) else {
            throw AnonServiceError.missingCommunityContext
        }
        return try await enroll(communityId: resolvedCommunityId)
    }

    func fetchProfile() async throws -> AnonProfile {
        let identity = try await ensureIdentity()
        return try await fetchProfile(id: identity.profileId)
    }

    func fetchProfile(id: Int) async throws -> AnonProfile {
        let dto: AnonProfileDTO = try await apiClient.get("/v1/anon/\(id)")
        return AnonProfile(
            id: dto.id,
            handle: dto.handle,
            companyId: dto.companyId,
            followerCount: dto.followerCount,
            followingCount: dto.followingCount,
            postsCount: dto.postsCount,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    func postContext(content: String, communityId: Int) async throws -> AnonPostContext {
        let identity = try await ensureIdentity(communityId: communityId)
        let privateKey = try loadOrCreatePrivateKey()
        let timestamp = Int(Date().timeIntervalSince1970)
        let contentHash = Data(content.utf8).sha256Hex
        let canonical = "v2|\(communityId)|\(contentHash)|\(timestamp)"
        let signature = try sign(message: canonical, privateKey: privateKey)

        return AnonPostContext(
            profileId: identity.profileId,
            cert: identity.cert,
            certKid: identity.certKid,
            signature: signature,
            timestamp: timestamp
        )
    }

    func actionContext(for action: AnonAction) async throws -> AnonActionContext {
        let identity = try await ensureIdentity()
        let privateKey = try loadOrCreatePrivateKey()
        let canonical: String

        switch action {
        case .like(let postId):
            canonical = "like|v1|\(postId)"
        case .save(let postId):
            canonical = "save|v1|\(postId)"
        case .unsave(let postId):
            canonical = "unsave|v1|\(postId)"
        case .comment(let postId):
            canonical = "comment|v1|\(postId)"
        case .commentLike(let commentId):
            canonical = "comment_like|v1|\(commentId)"
        case .commentList(let postId):
            canonical = "comment_list|v1|\(postId)"
        case .commentReplies(let commentId):
            canonical = "comment_replies|v1|\(commentId)"
        case .commentUserReplies(let userId):
            canonical = "comment_user_replies|v1|\(userId)"
        }

        let signature = try sign(message: canonical, privateKey: privateKey)
        return AnonActionContext(
            profileId: identity.profileId,
            cert: identity.cert,
            certKid: identity.certKid,
            signature: signature
        )
    }

    func revoke() async throws {
        let revoked = try await revokeIfPresent()
        if !revoked {
            throw AnonServiceError.missingIdentity
        }
    }

    @discardableResult
    func revokeIfPresent() async throws -> Bool {
        guard let identity = store.loadIdentity(),
              let privateKey = store.loadPrivateKey() else {
            store.clearAll()
            return false
        }
        let signature = try sign(message: "revoke|v1|\(identity.profileId)", privateKey: privateKey)
        let request = AnonRevokeRequestDTO(
            anonProfileId: identity.profileId,
            anonCert: identity.cert,
            anonCertKid: identity.certKid,
            anonSig: signature
        )
        let _: AnonRevokeResponseDTO = try await apiClient.post(
            "/anon/revoke",
            body: request,
            requiresAuth: false,
            headers: anonHeaders
        )
        store.clearAll()
        return true
    }

    func clearIdentity() {
        store.clearAll()
    }

    func backupState() -> AnonBackupState? {
        backupStore.loadState()
    }

    func createBackup(passphrase: String) async throws -> AnonBackupState {
        _ = try await ensureIdentity()
        guard let privateKey = store.loadPrivateKey() else {
            throw AnonCryptoError.encryptionFailed
        }
        let salt = try AnonCrypto.randomSalt()
        let encrypted = try AnonCrypto.encrypt(
            data: privateKey.rawRepresentation,
            passphrase: passphrase,
            salt: salt
        )
        let blobId = UUID().uuidString.lowercased()
        let request = AnonBackupRequestDTO(
            blobId: blobId,
            salt: salt.base64EncodedString(),
            ciphertext: encrypted.base64EncodedString(),
            expiresAt: nil
        )
        let _: EmptyResponse = try await apiClient.post("/anon/backup", body: request, headers: anonHeaders)
        let state = AnonBackupState(blobId: blobId, createdAt: Date())
        backupStore.saveState(state)
        return state
    }

    func restoreBackup(blobId: String, passphrase: String) async throws -> AnonIdentity {
        let trimmedBlobId = blobId.trimmingCharacters(in: .whitespacesAndNewlines)
        let response: AnonBackupResponseDTO = try await apiClient.get(
            "/anon/backup/\(trimmedBlobId)",
            headers: anonHeaders
        )
        guard let salt = Data(base64Encoded: response.salt),
              let ciphertext = Data(base64Encoded: response.ciphertext) else {
            throw AnonCryptoError.decryptionFailed
        }
        let decrypted = try AnonCrypto.decrypt(data: ciphertext, passphrase: passphrase, salt: salt)
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: decrypted)
        store.savePrivateKey(privateKey)
        guard let communityId = resolveCommunityId(explicit: nil) else {
            throw AnonServiceError.missingCommunityContext
        }
        let identity = try await enroll(using: privateKey, communityId: communityId)
        let state = AnonBackupState(blobId: trimmedBlobId, createdAt: Date())
        backupStore.saveState(state)
        return identity
    }

    private func enroll(communityId: Int) async throws -> AnonIdentity {
        let privateKey = try loadOrCreatePrivateKey()
        return try await enroll(using: privateKey, communityId: communityId)
    }

    private func enroll(using privateKey: Curve25519.Signing.PrivateKey, communityId: Int) async throws -> AnonIdentity {
        let publicKey = privateKey.publicKey.rawRepresentation.base64EncodedString()
        let certMessage = "anon-cert|v1|\(publicKey)"
        let certHash = Data(certMessage.utf8).sha256

        let issuerPem = try await fetchIssuerPEM(communityId: communityId)
        let rsaKey = try signer.parsePublicKey(pem: issuerPem)
        let blindResult = try signer.blind(message: certHash, with: rsaKey)

        let issueRequest = AnonIssueRequestDTO(
            communityId: communityId,
            blindedMessage: blindResult.blinded.base64EncodedString()
        )
        let issueResponse: AnonIssueResponseDTO = try await apiClient.post(
            "/anon/issue",
            body: issueRequest,
            headers: anonHeaders
        )
        guard let blindedSignature = Data(base64Encoded: issueResponse.blindedSignature) else {
            throw RSAKeyError.invalidDER
        }

        let unblinded = try signer.unblind(signature: blindedSignature, context: blindResult.context)
        let registerRequest = AnonRegisterRequestDTO(
            personaPubkey: publicKey,
            anonCert: unblinded.base64EncodedString(),
            anonCertKid: issueResponse.anonCertKid
        )
        let registerResponse: AnonRegisterResponseDTO = try await apiClient.post(
            "/anon/register",
            body: registerRequest,
            requiresAuth: false,
            headers: anonHeaders
        )
        let identity = AnonIdentity(
            profileId: registerResponse.anonProfileId,
            handle: registerResponse.handle,
            cert: unblinded.base64EncodedString(),
            certKid: registerResponse.anonCertKid,
            certExpiresAt: registerResponse.expiresAt
        )
        store.saveIdentity(identity)
        return identity
    }

    private func fetchIssuerPEM(communityId: Int) async throws -> String {
        let endpoint = "/anon/issuer?communityId=\(communityId)"
        let response: AnonIssuerResponseDTO = try await apiClient.get(endpoint, headers: anonHeaders)
        let pem = response.publicKeyPem.trimmingCharacters(in: .whitespacesAndNewlines)
        if pem.isEmpty {
            throw RSAKeyError.invalidPEM
        }
        return pem
    }

    private func resolveCommunityId(explicit: Int?) -> Int? {
        if let explicit, explicit > 0 {
            return explicit
        }
        let lastPosted = UserDefaults.standard.integer(forKey: lastPostedCommunityKey)
        if lastPosted > 0 {
            return lastPosted
        }
        let lastSelected = UserDefaults.standard.integer(forKey: lastSelectedCommunityKey)
        if lastSelected > 0 {
            return lastSelected
        }
        return nil
    }

    private func loadOrCreatePrivateKey() throws -> Curve25519.Signing.PrivateKey {
        if let existing = store.loadPrivateKey() {
            return existing
        }
        let newKey = Curve25519.Signing.PrivateKey()
        store.savePrivateKey(newKey)
        return newKey
    }

    private func sign(message: String, privateKey: Curve25519.Signing.PrivateKey) throws -> String {
        let digest = Data(message.utf8).sha256
        let signature = try privateKey.signature(for: digest)
        return signature.base64EncodedString()
    }
}

private extension Data {
    var sha256: Data {
        Data(SHA256.hash(data: self))
    }

    var sha256Hex: String {
        SHA256.hash(data: self).compactMap { String(format: "%02x", $0) }.joined()
    }
}
