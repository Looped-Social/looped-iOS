import Foundation

struct CommunityFollowResponseDTO: Codable {
    let items: [CommunityFollowDTO]
    let nextCursor: String?
}

struct CommunityFollowDTO: Codable {
    let id: Int
    let name: String
    let shortName: String?
    let kind: String?
    let memberCount: Int?
    let isPinned: Bool?
    let sortOrder: Int?
    let canPost: Bool?
    let isJoined: Bool?
}

struct CommunitySearchResponseDTO: Codable {
    let items: [CommunitySearchDTO]
    let nextCursor: String?
}

struct CommunitySearchDTO: Codable {
    let id: Int
    let name: String
    let shortName: String?
    let description: String?
    let kind: String?
    let specializationType: String?
    let memberCount: Int?
    let bannerImageUrl: String?
    let profileImageUrl: String?
    let imageUrl: String?
    let iconImageUrl: String?
    let icon: CommunityIcon?
    let isFollowing: Bool?
    let isJoined: Bool?
}

struct CommunityRecommendedResponseDTO: Codable {
    let items: [CommunityRecommendedDTO]
    let nextCursor: String?
}

struct CommunityRecommendedDTO: Codable {
    let id: Int
    let name: String
    let shortName: String?
    let description: String?
    let kind: String?
    let specializationType: String?
    let memberCount: Int?
    let isFollowing: Bool?
    let isJoined: Bool?
    let bannerImageUrl: String?
    let profileImageUrl: String?
    let imageUrl: String?
    let iconImageUrl: String?
    let icon: CommunityIcon?
}

struct CommunityDetailsDTO: Codable {
    let id: Int
    let name: String
    let shortName: String?
    let description: String?
    let kind: String?
    let specializationType: String?
    let memberCount: Int?
    let bannerImageUrl: String?
    let profileImageUrl: String?
    let imageUrl: String?
    let iconImageUrl: String?
    let icon: CommunityIcon?
    let isFollowing: Bool?
    let isJoined: Bool?
    let joinLimit: SpecializationJoinLimitDTO?
    let viewer: CommunityViewerDTO?
}

struct CommunityViewerDTO: Codable {
    let verificationStatus: CommunityViewerVerificationStatusDTO?
    let verificationVerifiedAt: Date?
    let verificationExpiresAt: Date?
    let canPost: Bool?
    let cannotPostReason: CommunityViewerCannotPostReasonDTO?
}

enum CommunityViewerVerificationStatusDTO: String, Codable {
    case active
    case pending
    case rejected
    case expired
    case none
    case unknown
}

enum CommunityViewerCannotPostReasonDTO: String, Codable {
    case notVerified = "not_verified"
    case notJoined = "not_joined"
    case suspended
    case readOnly = "read_only"
    case rateLimited = "rate_limited"
    case unknown
}

struct CommunityDomainsResponseDTO: Codable {
    let items: [String]
}

struct CommunityPermissionsDTO: Codable {
    let canPost: Bool
    let requiresVerification: Bool
    let requiresJoin: Bool?
}

struct DisplayCommunityDTO: Codable {
    let id: Int
    let name: String
    let shortName: String?
    let kind: String?
    let specializationType: String?
    let iconImageUrl: String?
    let icon: CommunityIcon?
}
