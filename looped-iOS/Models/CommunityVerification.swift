import Foundation

enum CommunityVerificationMethod: String, CaseIterable {
    case email
    case video
    case thirdparty

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .video: return "Video"
        case .thirdparty: return "Third-Party"
        }
    }
}

struct CommunityVerification: Identifiable, Equatable {
    let communityId: Int
    let communityName: String
    let communityKind: CommunityKind
    let method: CommunityVerificationMethod?
    let verified: Bool
    let verifiedAt: Date?
    let expiresAt: Date?
    let active: Bool

    var id: Int { communityId }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    var isActive: Bool {
        verified && active && !isExpired
    }
}

extension CommunityVerification {
    init(dto: CommunityVerificationDTO) {
        communityId = dto.communityId
        communityName = dto.communityName
        communityKind = CommunityKind(rawValue: dto.communityKind ?? "") ?? .unknown
        method = dto.method.flatMap { CommunityVerificationMethod(rawValue: $0) }
        verified = dto.verified
        verifiedAt = dto.verifiedAt
        expiresAt = dto.expiresAt
        active = dto.active ?? dto.verified
    }
}

struct CommunityVerificationStartResponse: Equatable {
    let status: String
    let method: CommunityVerificationMethod?
    let devCode: String?
    let sessionId: String?
    let instructions: String?
}

struct CommunityVerificationFinishRequest {
    let method: CommunityVerificationMethod
    let code: String?
    let mediaKey: String?
    let token: String?
}

struct CommunityVerificationFinishResponse: Equatable {
    let verified: Bool
    let status: String
    let expiresAt: Date?
}

struct CommunityVerificationUnverifyResponse: Equatable {
    let status: String
}

extension CommunityVerificationStartResponse {
    init(dto: CommunityVerificationStartResponseDTO) {
        status = dto.status
        method = dto.method.flatMap { CommunityVerificationMethod(rawValue: $0) }
        devCode = dto.devCode
        sessionId = dto.sessionId
        instructions = dto.instructions
    }
}

extension CommunityVerificationFinishResponse {
    init(dto: CommunityVerificationFinishResponseDTO) {
        verified = dto.verified
        status = dto.status
        expiresAt = dto.expiresAt
    }
}

extension CommunityVerificationUnverifyResponse {
    init(dto: CommunityVerificationUnverifyResponseDTO) {
        status = dto.status
    }
}
