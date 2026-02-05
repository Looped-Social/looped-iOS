import Foundation

struct CommunityVerificationListDTO: Decodable {
    let items: [CommunityVerificationDTO]
}

struct CommunityVerificationDTO: Decodable {
    let communityId: Int
    let communityName: String
    let communityKind: String?
    let method: String?
    let verified: Bool
    let verifiedAt: Date?
    let expiresAt: Date?
    let active: Bool?
    let status: String?
    let rejectReason: String?
    let email: String?
    let verifiedEmail: String?
}

struct CommunityVerificationStartRequestDTO: Encodable {
    let method: String
    let email: String?
}

struct CommunityVerificationStartResponseDTO: Decodable {
    let status: String
    let method: String?
    let devCode: String?
    let sessionId: String?
    let instructions: String?
}

struct CommunityVerificationFinishRequestDTO: Encodable {
    let method: String
    let code: String?
    let mediaKey: String?
    let token: String?
    let email: String?
}

struct CommunityVerificationFinishResponseDTO: Decodable {
    let verified: Bool
    let status: String
    let expiresAt: Date?
}

struct CommunityVerificationUnverifyResponseDTO: Decodable {
    let status: String
}
