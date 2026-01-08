import Foundation

struct Post: Codable, Identifiable {
    let id: UUID
    let backendId: Int?
    let authorBackendId: Int?
    let anonProfileId: Int?
    let content: String
    let authorId: UUID
    let authorDisplayName: String?
    let authorHandle: String?
    let authorFirstName: String?
    let authorLastName: String?
    let authorProfileImageURL: String?
    let company: String
    let communityId: Int?
    let communityName: String?
    let communityKind: CommunityKind?
    let isAnonymous: Bool
    let reactionCount: Int
    let commentsCount: Int
    let shareCount: Int
    let userReaction: ReactionType?
    let mediaAssetId: Int?
    let attachments: [MediaAttachment]?
    let isSaved: Bool
    let authorDisplayCommunity: DisplayCommunity?
    let authorDisplaySpecialization: DisplayCommunity?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        backendId: Int? = nil,
        authorBackendId: Int? = nil,
        anonProfileId: Int? = nil,
        content: String,
        authorId: UUID,
        authorDisplayName: String? = nil,
        authorHandle: String? = nil,
        authorFirstName: String? = nil,
        authorLastName: String? = nil,
        authorProfileImageURL: String? = nil,
        company: String,
        communityId: Int? = nil,
        communityName: String? = nil,
        communityKind: CommunityKind? = nil,
        isAnonymous: Bool,
        reactionCount: Int,
        commentsCount: Int = 0,
        shareCount: Int = 0,
        userReaction: ReactionType? = nil,
        mediaAssetId: Int? = nil,
        attachments: [MediaAttachment]? = nil,
        isSaved: Bool = false,
        authorDisplayCommunity: DisplayCommunity? = nil,
        authorDisplaySpecialization: DisplayCommunity? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.backendId = backendId
        self.authorBackendId = authorBackendId
        self.anonProfileId = anonProfileId
        self.content = content
        self.authorId = authorId
        self.authorDisplayName = authorDisplayName
        self.authorHandle = authorHandle
        self.authorFirstName = authorFirstName
        self.authorLastName = authorLastName
        self.authorProfileImageURL = authorProfileImageURL
        self.company = company
        self.communityId = communityId
        self.communityName = communityName
        self.communityKind = communityKind
        self.isAnonymous = isAnonymous
        self.reactionCount = reactionCount
        self.commentsCount = commentsCount
        self.shareCount = shareCount
        self.userReaction = userReaction
        self.mediaAssetId = mediaAssetId
        self.attachments = attachments
        self.isSaved = isSaved
        self.authorDisplayCommunity = authorDisplayCommunity
        self.authorDisplaySpecialization = authorDisplaySpecialization
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
    init(dto: PostDTO, isAnonymousOverride: Bool? = nil) {
        let resolvedIsAnonymous = isAnonymousOverride ?? dto.authorIsAnonymous ?? dto.isAnonymous ?? false
        let resolvedHandle = dto.authorHandle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedFirstName = dto.authorFirstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLastName = dto.authorLastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullName = [resolvedFirstName, resolvedLastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let trimmedDisplayName = dto.authorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = fullName.isEmpty ? trimmedDisplayName : fullName
        let authorIdValue: Int? = dto.authorId ?? dto.anonProfileId
        let resolvedAuthorId = authorIdValue.map(UUID.fromBackendId) ?? UUID()
        let resolvedReaction: ReactionType? = (dto.userLiked ?? false) ? .like : nil
        self.init(
            id: UUID(),
            backendId: dto.id,
            authorBackendId: dto.authorId,
            anonProfileId: dto.anonProfileId,
            content: dto.content,
            authorId: resolvedAuthorId,
            authorDisplayName: resolvedDisplayName,
            authorHandle: resolvedHandle,
            authorFirstName: resolvedFirstName,
            authorLastName: resolvedLastName,
            authorProfileImageURL: dto.authorProfileImageUrl,
            company: "",
            communityId: dto.communityId,
            communityName: dto.communityName,
            communityKind: CommunityKind(rawValue: dto.communityKind ?? ""),
            isAnonymous: resolvedIsAnonymous,
            reactionCount: dto.likesCount ?? 0,
            commentsCount: dto.commentsCount ?? 0,
            shareCount: dto.shareCount ?? 0,
            userReaction: resolvedReaction,
            mediaAssetId: dto.mediaAssetId,
            attachments: nil,
            isSaved: dto.isSaved ?? false,
            authorDisplayCommunity: dto.authorDisplayCommunity.map(DisplayCommunity.init(dto:)),
            authorDisplaySpecialization: dto.authorDisplaySpecialization.map(DisplayCommunity.init(dto:)),
            createdAt: dto.createdAt,
            updatedAt: dto.createdAt
        )
    }

    func updating(
        backendId: Int? = nil,
        reactionCount: Int? = nil,
        commentsCount: Int? = nil,
        shareCount: Int? = nil,
        userReaction: ReactionType?? = nil,
        isSaved: Bool? = nil,
        communityName: String? = nil,
        communityKind: CommunityKind? = nil,
        authorDisplayCommunity: DisplayCommunity? = nil,
        authorDisplaySpecialization: DisplayCommunity? = nil,
        updatedAt: Date? = nil
    ) -> Post {
        Post(
            id: id,
            backendId: backendId ?? self.backendId,
            authorBackendId: authorBackendId,
            anonProfileId: anonProfileId,
            content: content,
            authorId: authorId,
            authorDisplayName: authorDisplayName,
            authorHandle: authorHandle,
            authorFirstName: authorFirstName,
            authorLastName: authorLastName,
            authorProfileImageURL: authorProfileImageURL,
            company: company,
            communityId: communityId,
            communityName: communityName ?? self.communityName,
            communityKind: communityKind ?? self.communityKind,
            isAnonymous: isAnonymous,
            reactionCount: reactionCount ?? self.reactionCount,
            commentsCount: commentsCount ?? self.commentsCount,
            shareCount: shareCount ?? self.shareCount,
            userReaction: userReaction ?? self.userReaction,
            mediaAssetId: mediaAssetId,
            attachments: attachments,
            isSaved: isSaved ?? self.isSaved,
            authorDisplayCommunity: authorDisplayCommunity ?? self.authorDisplayCommunity,
            authorDisplaySpecialization: authorDisplaySpecialization ?? self.authorDisplaySpecialization,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
    }
}

extension Post {
    var resolvedAuthorName: String {
        if isAnonymous { return "Anonymous" }
        if let name = normalized(authorFirstName, authorLastName) {
            return name
        }
        if let displayName = normalized(authorDisplayName) {
            return displayName
        }
        return "User"
    }

    var resolvedAuthorHandle: String {
        if let handle = normalized(authorHandle) {
            return handle
        }
        if let displayName = normalized(authorDisplayName) {
            return displayName.lowercased().replacingOccurrences(of: " ", with: "")
        }
        return "user"
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalized(_ firstName: String?, _ lastName: String?) -> String? {
        let parts = [normalized(firstName), normalized(lastName)].compactMap { $0 }
        let fullName = parts.joined(separator: " ")
        return fullName.isEmpty ? nil : fullName
    }
}

extension Post {
    var authorDisplaySpecializationLine: String? {
        guard !isAnonymous else { return nil }
        let specializationName = normalizedOptional(authorDisplaySpecialization?.name)
        let communityName = normalizedOptional(authorDisplayCommunity?.name)
        if let communityName {
            return "\(specializationName ?? "Member") @ \(communityName)"
        }
        if let specializationName {
            return specializationName
        }
        return nil
    }

    private func normalizedOptional(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
