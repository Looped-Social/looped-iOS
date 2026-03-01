import Foundation

struct AppAttestChallengeRequestDTO: Encodable {}

struct AppAttestChallengeResponseDTO: Decodable {
    let mode: String
    let requiredForAnonEnrollment: Bool
    let enabled: Bool?
    let challengeId: String?
    let challenge: String?
    let expiresAt: Date?
}

struct AppAttestCompleteRequestDTO: Encodable {
    let challengeId: String
    let keyId: String
    let attestationObject: String
    let assertionObject: String?
}

struct AppAttestCompleteResponseDTO: Decodable {
    let mode: String
    let requiredForAnonEnrollment: Bool
    let trusted: Bool
    let status: String
    let keyId: String?
    let trustedUntil: Date?
    let lastVerifiedAt: Date?
    let lastError: String?
}

struct AppAttestStatusResponseDTO: Decodable {
    let mode: String
    let requiredForAnonEnrollment: Bool
    let trusted: Bool
    let keyId: String?
    let status: String
    let trustedUntil: Date?
    let lastVerifiedAt: Date?
    let lastChallengeAt: Date?
    let lastSeenAt: Date?
    let lastError: String?
}
