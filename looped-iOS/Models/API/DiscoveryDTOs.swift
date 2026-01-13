import Foundation

struct LoopSearchResponseDTO: Codable {
    let items: [LoopDTO]
    let nextCursor: String?
}

struct LoopDTO: Codable {
    let id: Int
    let name: String
    let description: String
    /// Number of active verified members (backend `member_count`).
    let memberCount: Int
}

struct HashtagSearchResponseDTO: Codable {
    let items: [HashtagDTO]
    let nextCursor: String?
}

struct HashtagDTO: Codable {
    let name: String
    let usageCount: Int
}
