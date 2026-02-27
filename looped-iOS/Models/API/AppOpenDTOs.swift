import Foundation

struct AppOpenRequestDTO: Encodable {
    let openedAt: String?
    let activeCommunityId: Int?
    let seenCommunityIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case openedAt = "opened_at"
        case activeCommunityId = "active_community_id"
        case seenCommunityIds = "seen_community_ids"
    }
}

struct AppOpenResponseDTO: Decodable {
    let lastAppOpenAt: Date
    let updatedCommunities: [AppOpenUpdatedCommunityDTO]
}

struct AppOpenUpdatedCommunityDTO: Decodable {
    let communityId: Int
    let seenAt: Date
}

