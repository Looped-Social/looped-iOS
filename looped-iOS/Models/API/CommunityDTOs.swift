import Foundation

struct CommunityFollowResponseDTO: Codable {
    let items: [CommunityFollowDTO]
    let nextCursor: String?
}

struct CommunityFollowDTO: Codable {
    let id: Int
    let name: String
    let kind: String?
    let memberCount: Int?
    let isPinned: Bool?
    let sortOrder: Int?
    let canPost: Bool?
}

struct CommunitySearchResponseDTO: Codable {
    let items: [CommunitySearchDTO]
    let nextCursor: String?
}

struct CommunitySearchDTO: Codable {
    let id: Int
    let name: String
    let description: String
    let kind: String?
    let memberCount: Int?
}
