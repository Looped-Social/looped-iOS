import Foundation

struct UserContentResponseDTO: Codable {
    let items: [UserContentItemDTO]
    let nextCursor: String?
}

struct UserContentItemDTO: Codable {
    let type: String
    let createdAt: Date
    let post: PostDTO?
    let reply: UserContentReplyDTO?
}

struct UserContentReplyDTO: Codable {
    let id: Int
    let postId: Int
    let content: String
    let createdAt: Date
    let isDeleted: Bool?
    let parentId: Int?
}

