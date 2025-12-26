import Foundation

struct AnonIssueRequestDTO: Encodable {
    let communityId: Int
    let blindedMessage: String
}

struct AnonIssueResponseDTO: Decodable {
    let anonCertKid: String
    let blindedSignature: String
    let expiresAt: Date
}

struct AnonRegisterRequestDTO: Encodable {
    let personaPubkey: String
    let anonCert: String
    let anonCertKid: String
}

struct AnonRegisterResponseDTO: Decodable {
    let anonProfileId: Int
    let handle: String
    let anonCertKid: String
    let expiresAt: Date
}

struct AnonProfileDTO: Decodable {
    let id: Int
    let handle: String
    let companyId: Int
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let createdAt: Date?
    let updatedAt: Date?
}

struct AnonRevokeRequestDTO: Encodable {
    let anonProfileId: Int
    let anonCert: String
    let anonCertKid: String
    let anonSig: String
}

struct AnonRevokeResponseDTO: Decodable {
    let revoked: Bool
    let alreadyRevoked: Bool?
}

struct AnonIssuerResponseDTO: Decodable {
    let publicKeyPem: String
    let kid: String?
    let alg: String?
    let expiresAt: Date?
}

struct AnonBackupRequestDTO: Encodable {
    let blobId: String
    let salt: String
    let ciphertext: String
    let expiresAt: Date?
}

struct AnonBackupResponseDTO: Decodable {
    let salt: String
    let ciphertext: String
    let expiresAt: Date?
}

struct AnonResetResponseDTO: Decodable {
    let reset: Bool
    let cleared: Bool
}
