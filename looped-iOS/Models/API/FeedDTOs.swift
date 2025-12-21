import Foundation

struct FeedResponseDTO: Codable {
    let items: [PostDTO]
    let nextCursor: String?
}

struct PostDTO: Codable {
    let id: Int
    let authorId: Int
    let companyId: Int
    let communityId: Int?
    let content: String
    let mediaAssetId: Int?
    let likesCount: Int
    let commentsCount: Int?
    let shareCount: Int?
    let createdAt: Date
    let isSaved: Bool?
}

struct CreatePostRequestDTO: Codable {
    let content: String
    let mediaAssetId: Int?
    let communityId: Int
}

struct PostLikeResponseDTO: Codable {
    let postId: Int
    let likesCount: Int
}

struct PostSaveResponseDTO: Codable {
    let postId: Int
    let saved: Bool
}
