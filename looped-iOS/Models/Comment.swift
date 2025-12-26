import Foundation

struct Comment: Codable, Identifiable {
    let id: UUID
    let backendId: Int?
    let postId: UUID
    let postBackendId: Int?
    let content: String
    let authorId: UUID
    let authorBackendId: Int?
    let authorDisplayName: String?
    let authorHandle: String?
    let authorProfileImageURL: String?
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
        backendId: Int? = nil,
        postId: UUID,
        postBackendId: Int? = nil,
        content: String,
        authorId: UUID,
        authorBackendId: Int? = nil,
        authorDisplayName: String? = nil,
        authorHandle: String? = nil,
        authorProfileImageURL: String? = nil,
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
        self.backendId = backendId
        self.postId = postId
        self.postBackendId = postBackendId
        self.content = content
        self.authorId = authorId
        self.authorBackendId = authorBackendId
        self.authorDisplayName = isAnonymous ? nil : authorDisplayName
        self.authorHandle = authorHandle
        self.authorProfileImageURL = authorProfileImageURL
        self.company = company
        self.isAnonymous = isAnonymous
        self.likeCount = likeCount
        self.userLiked = userLiked
        self.isLikedByCreator = isLikedByCreator
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.replyToCommentId = replyToCommentId
    }

    init(dto: CommentDTO) {
        let resolvedIsAnonymous = dto.authorIsAnonymous ?? dto.isAnonymous ?? false
        self.init(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            postId: UUID.fromBackendId(dto.postId),
            postBackendId: dto.postId,
            content: dto.content,
            authorId: UUID.fromBackendId(dto.author.id),
            authorBackendId: dto.author.id,
            authorDisplayName: dto.author.displayName,
            authorHandle: dto.author.username ?? dto.author.handle,
            authorProfileImageURL: dto.author.profileImageUrl,
            company: "",
            isAnonymous: resolvedIsAnonymous,
            likeCount: dto.likesCount,
            userLiked: dto.userLiked ?? false,
            isLikedByCreator: dto.likedByCreator ?? false,
            createdAt: dto.createdAt,
            updatedAt: dto.createdAt,
            replyToCommentId: dto.parentId.map(UUID.fromBackendId)
        )
    }

    func updating(
        likeCount: Int? = nil,
        userLiked: Bool? = nil,
        isLikedByCreator: Bool? = nil
    ) -> Comment {
        Comment(
            id: id,
            backendId: backendId,
            postId: postId,
            postBackendId: postBackendId,
            content: content,
            authorId: authorId,
            authorBackendId: authorBackendId,
            authorDisplayName: authorDisplayName,
            authorHandle: authorHandle,
            authorProfileImageURL: authorProfileImageURL,
            company: company,
            isAnonymous: isAnonymous,
            likeCount: likeCount ?? self.likeCount,
            userLiked: userLiked ?? self.userLiked,
            isLikedByCreator: isLikedByCreator ?? self.isLikedByCreator,
            createdAt: createdAt,
            updatedAt: updatedAt,
            replyToCommentId: replyToCommentId
        )
    }
}
