import Foundation

struct Post: Codable, Identifiable {
    let id: UUID
    let backendId: Int?
    let authorBackendId: Int?
    let content: String
    let authorId: UUID
    let authorDisplayName: String?
    let company: String
    let isAnonymous: Bool
    let reactionCount: Int
    let userReaction: ReactionType?
    let mediaAssetId: Int?
    let attachments: [MediaAttachment]?
    let isSaved: Bool
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        backendId: Int? = nil,
        authorBackendId: Int? = nil,
        content: String,
        authorId: UUID,
        authorDisplayName: String? = nil,
        company: String,
        isAnonymous: Bool,
        reactionCount: Int,
        userReaction: ReactionType? = nil,
        mediaAssetId: Int? = nil,
        attachments: [MediaAttachment]? = nil,
        isSaved: Bool = false,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.backendId = backendId
        self.authorBackendId = authorBackendId
        self.content = content
        self.authorId = authorId
        self.authorDisplayName = authorDisplayName
        self.company = company
        self.isAnonymous = isAnonymous
        self.reactionCount = reactionCount
        self.userReaction = userReaction
        self.mediaAssetId = mediaAssetId
        self.attachments = attachments
        self.isSaved = isSaved
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum ReactionType: String, Codable, CaseIterable {
    case like = "like"
    case love = "love"
    case laugh = "laugh"
    case wow = "wow"
    case sad = "sad"
    case angry = "angry"
}

extension Post {
    init(dto: PostDTO) {
        self.init(
            id: UUID(),
            backendId: dto.id,
            authorBackendId: dto.authorId,
            content: dto.content,
            authorId: UUID.fromBackendId(dto.authorId),
            authorDisplayName: nil,
            company: "",
            isAnonymous: false,
            reactionCount: dto.likesCount,
            userReaction: nil,
            mediaAssetId: dto.mediaAssetId,
            attachments: nil,
            isSaved: dto.isSaved ?? false,
            createdAt: dto.createdAt,
            updatedAt: dto.createdAt
        )
    }

    func updating(
        backendId: Int? = nil,
        reactionCount: Int? = nil,
        userReaction: ReactionType?? = nil,
        isSaved: Bool? = nil,
        updatedAt: Date? = nil
    ) -> Post {
        Post(
            id: id,
            backendId: backendId ?? self.backendId,
            authorBackendId: authorBackendId,
            content: content,
            authorId: authorId,
            authorDisplayName: authorDisplayName,
            company: company,
            isAnonymous: isAnonymous,
            reactionCount: reactionCount ?? self.reactionCount,
            userReaction: userReaction ?? self.userReaction,
            mediaAssetId: mediaAssetId,
            attachments: attachments,
            isSaved: isSaved ?? self.isSaved,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
    }
}
