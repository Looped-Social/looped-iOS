import Foundation

struct FeedResponseDTO: Codable {
    let items: [PostDTO]
    let nextCursor: String?
}

struct PostDTO: Codable {
    let id: Int
    let authorId: Int
    let companyId: Int
    let content: String
    let mediaAssetId: Int?
    let likesCount: Int
    let createdAt: Date
}

struct CreatePostRequestDTO: Codable {
    let content: String
    let mediaAssetId: Int?
}

struct PostLikeResponseDTO: Codable {
    let postId: Int
    let likesCount: Int
}

