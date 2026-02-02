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
    let imageUrl: String?
    let isFollowing: Bool?
    let isJoined: Bool?
}

struct CommunityRecommendedResponseDTO: Codable {
    let items: [CommunityRecommendedDTO]
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
    let imageUrl: String?
}

struct CommunityDetailsDTO: Codable {
    let id: Int
    let name: String
    let shortName: String?
    let description: String?
    let kind: String?
    let specializationType: String?
    let memberCount: Int?
    let imageUrl: String?
    let isFollowing: Bool?
    let isJoined: Bool?
    let joinLimit: SpecializationJoinLimitDTO?
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
}
