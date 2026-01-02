import Foundation

struct UserCommentsResponseDTO: Codable {
    let items: [UserCommentDTO]
    let nextCursor: String?
}

struct UserCommentDTO: Codable {
    let id: Int
    let postId: Int
    let content: String
    let createdAt: Date
    let parentId: Int?
    let isDeleted: Bool?
}
