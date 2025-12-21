import Foundation

struct AnonEnrollRequestDTO: Codable {
    let personaPubkey: String
    let blindedMessage: String
}

struct AnonEnrollResponseDTO: Codable {
    let anonProfileId: Int
    let handle: String
    let companyId: Int
    let anonCertKid: String
    let blindedSignature: String
    let expiresAt: Date
}

struct AnonProfileDTO: Codable {
    let id: Int
    let handle: String
    let companyId: Int
    let followerCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let createdAt: Date?
    let updatedAt: Date?
}

struct AnonRevokeRequestDTO: Codable {
    let anonProfileId: Int
    let anonCert: String
    let anonCertKid: String
    let anonSig: String
}

struct AnonIssuerResponseDTO: Codable {
    let publicKeyPem: String
    let kid: String?
    let alg: String?
    let expiresAt: Date?
}

struct AnonBackupRequestDTO: Codable {
    let blobId: String
    let salt: String
    let ciphertext: String
    let expiresAt: Date?
}

struct AnonBackupResponseDTO: Codable {
    let salt: String
    let ciphertext: String
    let expiresAt: Date?
}
