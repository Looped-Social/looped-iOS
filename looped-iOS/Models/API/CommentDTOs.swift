import Foundation

struct CommentListResponseDTO: Codable {
    let items: [CommentDTO]
    let nextCursor: String?
}

struct CommentDTO: Codable {
    let id: Int
    let postId: Int
    let parentId: Int?
    let author: CommentAuthorDTO
    let isAnonymous: Bool
    let content: String
    let likesCount: Int
    let userLiked: Bool?
    let likedByCreator: Bool?
    let createdAt: Date
}

struct CommentAuthorDTO: Codable {
    let id: Int
    let displayName: String?
    let username: String?
    let handle: String?
    let companyId: Int
    let profileImageUrl: String?
}

struct CreateCommentRequestDTO: Codable {
    let content: String
    let parentId: Int?
}

struct CommentLikeResponseDTO: Codable {
    let commentId: Int
    let likesCount: Int
    let userLiked: Bool?
    let likedByCreator: Bool?
}
