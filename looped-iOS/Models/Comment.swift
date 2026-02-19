import Foundation

struct Comment: Codable, Identifiable {
    let id: UUID
    let backendId: Int?
    let postId: UUID
    let postBackendId: Int?
    let content: String
    let mediaAssetId: Int?
    let attachments: [MediaAttachment]?
    let authorId: UUID
    let authorBackendId: Int?
    let authorDisplayName: String?
    let authorHandle: String?
    let authorProfileImageURL: String?
    let company: String
    let isAnonymous: Bool
    let isDeleted: Bool
    let isUnderReview: Bool
    let likeCount: Int
    let replyCount: Int
    let totalReplyCount: Int?
    let userLiked: Bool
    let isLikedByCreator: Bool
    let createdAt: Date
    let updatedAt: Date
    let replyToCommentId: UUID?
    let replyToBackendId: Int?
    
    init(
        id: UUID = UUID(),
        backendId: Int? = nil,
        postId: UUID,
        postBackendId: Int? = nil,
        content: String,
        mediaAssetId: Int? = nil,
        attachments: [MediaAttachment]? = nil,
        authorId: UUID,
        authorBackendId: Int? = nil,
        authorDisplayName: String? = nil,
        authorHandle: String? = nil,
        authorProfileImageURL: String? = nil,
        company: String,
        isAnonymous: Bool = false,
        isDeleted: Bool = false,
        isUnderReview: Bool = false,
        likeCount: Int = 0,
        replyCount: Int = 0,
        totalReplyCount: Int? = nil,
        userLiked: Bool = false,
        isLikedByCreator: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        replyToCommentId: UUID? = nil,
        replyToBackendId: Int? = nil
    ) {
        self.id = id
        self.backendId = backendId
        self.postId = postId
        self.postBackendId = postBackendId
        self.content = content
        self.mediaAssetId = mediaAssetId
        self.attachments = attachments
        self.authorId = authorId
        self.authorBackendId = authorBackendId
        self.authorDisplayName = isAnonymous ? nil : authorDisplayName
        self.authorHandle = authorHandle
        self.authorProfileImageURL = authorProfileImageURL
        self.company = company
        self.isAnonymous = isAnonymous
        self.isDeleted = isDeleted
        self.isUnderReview = isUnderReview
        self.likeCount = likeCount
        self.replyCount = replyCount
        self.totalReplyCount = totalReplyCount
        self.userLiked = userLiked
        self.isLikedByCreator = isLikedByCreator
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.replyToCommentId = replyToCommentId
        self.replyToBackendId = replyToBackendId
    }

    // Backward-compatible initializer (pre-media support) to avoid stale-object linker issues.
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
        isDeleted: Bool = false,
        likeCount: Int = 0,
        replyCount: Int = 0,
        totalReplyCount: Int? = nil,
        userLiked: Bool = false,
        isLikedByCreator: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        replyToCommentId: UUID? = nil,
        replyToBackendId: Int? = nil
    ) {
        self.init(
            id: id,
            backendId: backendId,
            postId: postId,
            postBackendId: postBackendId,
            content: content,
            mediaAssetId: nil,
            attachments: nil,
            authorId: authorId,
            authorBackendId: authorBackendId,
            authorDisplayName: authorDisplayName,
            authorHandle: authorHandle,
            authorProfileImageURL: authorProfileImageURL,
            company: company,
            isAnonymous: isAnonymous,
            isDeleted: isDeleted,
            likeCount: likeCount,
            replyCount: replyCount,
            totalReplyCount: totalReplyCount,
            userLiked: userLiked,
            isLikedByCreator: isLikedByCreator,
            createdAt: createdAt,
            updatedAt: updatedAt,
            replyToCommentId: replyToCommentId,
            replyToBackendId: replyToBackendId
        )
    }

    init(dto: CommentDTO) {
        let author = dto.author
        let resolvedIsAnonymous = dto.authorIsAnonymous ?? author?.isAnonymous ?? dto.isAnonymous ?? false
        let trimmedDisplayName = author?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = author?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = [trimmedDisplayName, trimmedName]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .first
        let resolvedAuthorBackendId = author?.id ?? dto.authorPrincipalId ?? author?.principalId
        self.init(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            postId: UUID.fromBackendId(dto.postId),
            postBackendId: dto.postId,
            content: dto.content,
            mediaAssetId: dto.mediaAssetId,
            attachments: nil,
            authorId: resolvedAuthorBackendId.map(UUID.fromBackendId) ?? UUID(),
            authorBackendId: resolvedAuthorBackendId,
            authorDisplayName: resolvedDisplayName,
            authorHandle: author?.username ?? author?.handle,
            authorProfileImageURL: author?.profileImageUrl,
            company: "",
            isAnonymous: resolvedIsAnonymous,
            isDeleted: dto.isDeleted ?? false,
            isUnderReview: dto.isUnderReview ?? false,
            likeCount: dto.likesCount,
            replyCount: dto.replyCount ?? 0,
            totalReplyCount: dto.totalReplyCount ?? dto.descendantReplyCount ?? dto.threadReplyCount,
            userLiked: dto.userLiked ?? false,
            isLikedByCreator: dto.likedByCreator ?? false,
            createdAt: dto.createdAt,
            updatedAt: dto.createdAt,
            replyToCommentId: dto.parentId.map(UUID.fromBackendId),
            replyToBackendId: dto.parentId
        )
    }

    func updating(
        content: String? = nil,
        likeCount: Int? = nil,
        userLiked: Bool? = nil,
        isLikedByCreator: Bool? = nil,
        replyCount: Int? = nil,
        totalReplyCount: Int?? = nil,
        isDeleted: Bool? = nil,
        attachments: [MediaAttachment]?? = nil
    ) -> Comment {
        Comment(
            id: id,
            backendId: backendId,
            postId: postId,
            postBackendId: postBackendId,
            content: content ?? self.content,
            mediaAssetId: mediaAssetId,
            attachments: attachments ?? self.attachments,
            authorId: authorId,
            authorBackendId: authorBackendId,
            authorDisplayName: authorDisplayName,
            authorHandle: authorHandle,
            authorProfileImageURL: authorProfileImageURL,
            company: company,
            isAnonymous: isAnonymous,
            isDeleted: isDeleted ?? self.isDeleted,
            isUnderReview: isUnderReview,
            likeCount: likeCount ?? self.likeCount,
            replyCount: replyCount ?? self.replyCount,
            totalReplyCount: totalReplyCount ?? self.totalReplyCount,
            userLiked: userLiked ?? self.userLiked,
            isLikedByCreator: isLikedByCreator ?? self.isLikedByCreator,
            createdAt: createdAt,
            updatedAt: updatedAt,
            replyToCommentId: replyToCommentId,
            replyToBackendId: replyToBackendId
        )
    }
}

extension Comment {
    var resolvedAuthorName: String {
        if isAnonymous {
            return "Anonymous"
        }
        if let displayName = normalized(authorDisplayName) {
            return displayName
        }
        if let handle = normalized(authorHandle) {
            if handle.hasPrefix("@") {
                return handle
            }
            return "@\(handle)"
        }
        return "User"
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
