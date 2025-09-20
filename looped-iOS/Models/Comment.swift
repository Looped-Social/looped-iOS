import Foundation

struct Comment: Codable, Identifiable {
    let id: UUID
    let postId: UUID
    let content: String
    let authorId: UUID
    let authorDisplayName: String?
    let company: String
    let isAnonymous: Bool
    let likeCount: Int
    let userLiked: Bool
    let isLikedByCreator: Bool
    let createdAt: Date
    let updatedAt: Date
    let replyToCommentId: UUID?
    
    init(
        id: UUID = UUID(),
        postId: UUID,
        content: String,
        authorId: UUID,
        authorDisplayName: String? = nil,
        company: String,
        isAnonymous: Bool = false,
        likeCount: Int = 0,
        userLiked: Bool = false,
        isLikedByCreator: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        replyToCommentId: UUID? = nil
    ) {
        self.id = id
        self.postId = postId
        self.content = content
        self.authorId = authorId
        self.authorDisplayName = isAnonymous ? nil : authorDisplayName
        self.company = company
        self.isAnonymous = isAnonymous
        self.likeCount = likeCount
        self.userLiked = userLiked
        self.isLikedByCreator = isLikedByCreator
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.replyToCommentId = replyToCommentId
    }
}