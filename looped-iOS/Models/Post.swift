import Foundation

struct Post: Codable, Identifiable {
    let id: UUID
    let backendId: Int?
    let authorBackendId: Int?
    let authorPrincipalId: Int?
    let anonProfileId: Int?
    let content: String
    let poll: Poll?
    let authorId: UUID
    let authorDisplayName: String?
    let authorHandle: String?
    let authorFirstName: String?
    let authorLastName: String?
    let authorProfileImageURL: String?
    let company: String
    let communityId: Int?
    let communityName: String?
    let communityShortName: String?
    let communityKind: CommunityKind?
    let isAnonymous: Bool
    let isUnderReview: Bool
    let reactionCount: Int
    let commentsCount: Int
    let shareCount: Int
    let repostCount: Int
    let viewerHasReposted: Bool
    let repostedByFollowedUsers: [RepostBannerUser]?
    let repostedByFollowedUsersCount: Int?
    let userReaction: ReactionType?
    let mediaAssetId: Int?
    let mediaAssetIds: [Int]?
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
        authorPrincipalId: Int? = nil,
        anonProfileId: Int? = nil,
        content: String,
        poll: Poll? = nil,
        authorId: UUID,
        authorDisplayName: String? = nil,
        authorHandle: String? = nil,
        authorFirstName: String? = nil,
        authorLastName: String? = nil,
        authorProfileImageURL: String? = nil,
        company: String,
        communityId: Int? = nil,
        communityName: String? = nil,
        communityShortName: String? = nil,
        communityKind: CommunityKind? = nil,
        isAnonymous: Bool,
        isUnderReview: Bool = false,
        reactionCount: Int,
        commentsCount: Int = 0,
        shareCount: Int = 0,
        repostCount: Int = 0,
        viewerHasReposted: Bool = false,
        repostedByFollowedUsers: [RepostBannerUser]? = nil,
        repostedByFollowedUsersCount: Int? = nil,
        userReaction: ReactionType? = nil,
        mediaAssetId: Int? = nil,
        mediaAssetIds: [Int]? = nil,
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
        self.authorPrincipalId = authorPrincipalId
        self.anonProfileId = anonProfileId
        self.content = content
        self.poll = poll
        self.authorId = authorId
        self.authorDisplayName = authorDisplayName
        self.authorHandle = authorHandle
        self.authorFirstName = authorFirstName
        self.authorLastName = authorLastName
        self.authorProfileImageURL = authorProfileImageURL
        self.company = company
        self.communityId = communityId
        self.communityName = communityName
        self.communityShortName = communityShortName
        self.communityKind = communityKind
        self.isAnonymous = isAnonymous
        self.isUnderReview = isUnderReview
        self.reactionCount = reactionCount
        self.commentsCount = commentsCount
        self.shareCount = shareCount
        self.repostCount = repostCount
        self.viewerHasReposted = viewerHasReposted
        self.repostedByFollowedUsers = repostedByFollowedUsers
        self.repostedByFollowedUsersCount = repostedByFollowedUsersCount
        self.userReaction = userReaction
        self.mediaAssetId = mediaAssetId
        self.mediaAssetIds = mediaAssetIds
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
        let resolvedMediaAssetIds: [Int]? = {
            let camel = (dto.mediaAssetIds ?? []).filter { $0 > 0 }
            if !camel.isEmpty { return camel }
            let snake = (dto.mediaAssetIdsSnake ?? []).filter { $0 > 0 }
            if !snake.isEmpty { return snake }
            return nil
        }()
        let resolvedMediaUrl = (dto.cdnUrl ?? dto.mediaUrl)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAttachments: [MediaAttachment]? = {
            if let ids = resolvedMediaAssetIds, ids.count > 1 {
                return nil
            }
            guard let resolvedMediaUrl, !resolvedMediaUrl.isEmpty else { return nil }
            let lowercased = resolvedMediaUrl.lowercased()
            let type: MediaType = lowercased.contains(".mp4") ? .video : .image
            if let mediaAssetId = dto.mediaAssetId, mediaAssetId > 0 {
                return [MediaAttachment(id: "asset:\(mediaAssetId)", type: type, url: resolvedMediaUrl)]
            }
            return [MediaAttachment(type: type, url: resolvedMediaUrl)]
        }()
        let bannerUsers = dto.repostedByFollowedUsers?.map(RepostBannerUser.init(dto:))
        let bannerCount = dto.repostedByFollowedUsersCount ?? bannerUsers?.count
        let resolvedPoll = dto.poll.map(Poll.init(dto:))
        let resolvedCommunityKind = CommunityKind(rawValue: dto.communityKind ?? "")
        let resolvedAuthorDisplayCommunity = dto.authorDisplayCommunity.map(DisplayCommunity.init(dto:))
        let resolvedAuthorDisplaySpecialization = dto.authorDisplaySpecialization.map(DisplayCommunity.init(dto:))
        let resolvedIsUnderReview = dto.isUnderReview ?? false
        self.init(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            authorBackendId: dto.authorId,
            authorPrincipalId: dto.authorPrincipalId,
            anonProfileId: dto.anonProfileId,
            content: dto.content,
            poll: resolvedPoll,
            authorId: resolvedAuthorId,
            authorDisplayName: resolvedDisplayName,
            authorHandle: resolvedHandle,
            authorFirstName: resolvedFirstName,
            authorLastName: resolvedLastName,
            authorProfileImageURL: dto.authorProfileImageUrl,
            company: "",
            communityId: dto.communityId,
            communityName: dto.communityName,
            communityShortName: dto.communityShortName,
            communityKind: resolvedCommunityKind,
            isAnonymous: resolvedIsAnonymous,
            isUnderReview: resolvedIsUnderReview,
            reactionCount: dto.likesCount ?? 0,
            commentsCount: dto.commentsCount ?? 0,
            shareCount: dto.shareCount ?? 0,
            repostCount: dto.repostCount ?? 0,
            viewerHasReposted: dto.viewerHasReposted ?? false,
            repostedByFollowedUsers: bannerUsers,
            repostedByFollowedUsersCount: bannerCount,
            userReaction: resolvedReaction,
            mediaAssetId: dto.mediaAssetId,
            mediaAssetIds: resolvedMediaAssetIds,
            attachments: resolvedAttachments,
            isSaved: dto.isSaved ?? false,
            authorDisplayCommunity: resolvedAuthorDisplayCommunity,
            authorDisplaySpecialization: resolvedAuthorDisplaySpecialization,
            createdAt: dto.createdAt,
            updatedAt: dto.createdAt
        )
    }

    func updating(
        backendId: Int? = nil,
        reactionCount: Int? = nil,
        commentsCount: Int? = nil,
        shareCount: Int? = nil,
        repostCount: Int? = nil,
        viewerHasReposted: Bool? = nil,
        repostedByFollowedUsers: [RepostBannerUser]?? = nil,
        repostedByFollowedUsersCount: Int?? = nil,
        userReaction: ReactionType?? = nil,
        attachments: [MediaAttachment]?? = nil,
        isSaved: Bool? = nil,
        communityName: String? = nil,
        communityShortName: String? = nil,
        communityKind: CommunityKind? = nil,
        authorDisplayCommunity: DisplayCommunity? = nil,
        authorDisplaySpecialization: DisplayCommunity? = nil,
        poll: Poll?? = nil,
        updatedAt: Date? = nil
    ) -> Post {
        let resolvedBackendId = backendId ?? self.backendId
        let resolvedPoll: Poll? = poll ?? self.poll
        let resolvedCommunityName = communityName ?? self.communityName
        let resolvedCommunityShortName = communityShortName ?? self.communityShortName
        let resolvedCommunityKind = communityKind ?? self.communityKind
        let resolvedReactionCount = reactionCount ?? self.reactionCount
        let resolvedCommentsCount = commentsCount ?? self.commentsCount
        let resolvedShareCount = shareCount ?? self.shareCount
        let resolvedRepostCount = repostCount ?? self.repostCount
        let resolvedViewerHasReposted = viewerHasReposted ?? self.viewerHasReposted
        let resolvedRepostedByFollowedUsers: [RepostBannerUser]? = repostedByFollowedUsers ?? self.repostedByFollowedUsers
        let resolvedRepostedByFollowedUsersCount: Int? = repostedByFollowedUsersCount ?? self.repostedByFollowedUsersCount
        let resolvedUserReaction: ReactionType? = userReaction ?? self.userReaction
        let resolvedAttachments: [MediaAttachment]? = attachments ?? self.attachments
        let resolvedIsSaved = isSaved ?? self.isSaved
        let resolvedAuthorDisplayCommunity = authorDisplayCommunity ?? self.authorDisplayCommunity
        let resolvedAuthorDisplaySpecialization = authorDisplaySpecialization ?? self.authorDisplaySpecialization
        let resolvedUpdatedAt = updatedAt ?? self.updatedAt

        return Post(
            id: id,
            backendId: resolvedBackendId,
            authorBackendId: authorBackendId,
            authorPrincipalId: authorPrincipalId,
            anonProfileId: anonProfileId,
            content: content,
            poll: resolvedPoll,
            authorId: authorId,
            authorDisplayName: authorDisplayName,
            authorHandle: authorHandle,
            authorFirstName: authorFirstName,
            authorLastName: authorLastName,
            authorProfileImageURL: authorProfileImageURL,
            company: company,
            communityId: communityId,
            communityName: resolvedCommunityName,
            communityShortName: resolvedCommunityShortName,
            communityKind: resolvedCommunityKind,
            isAnonymous: isAnonymous,
            isUnderReview: isUnderReview,
            reactionCount: resolvedReactionCount,
            commentsCount: resolvedCommentsCount,
            shareCount: resolvedShareCount,
            repostCount: resolvedRepostCount,
            viewerHasReposted: resolvedViewerHasReposted,
            repostedByFollowedUsers: resolvedRepostedByFollowedUsers,
            repostedByFollowedUsersCount: resolvedRepostedByFollowedUsersCount,
            userReaction: resolvedUserReaction,
            mediaAssetId: mediaAssetId,
            mediaAssetIds: mediaAssetIds,
            attachments: resolvedAttachments,
            isSaved: resolvedIsSaved,
            authorDisplayCommunity: resolvedAuthorDisplayCommunity,
            authorDisplaySpecialization: resolvedAuthorDisplaySpecialization,
            createdAt: createdAt,
            updatedAt: resolvedUpdatedAt
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
    func communityDisplayName(preferShortNames: Bool) -> String? {
        CommunityLabelText.preferredName(
            preferShortNames: preferShortNames,
            name: communityName,
            shortName: communityShortName
        )
    }

    func authorDisplaySpecializationLine(preferShortNames: Bool) -> String? {
        guard !isAnonymous else { return nil }
        let specializationName = CommunityLabelText.preferredName(
            preferShortNames: preferShortNames,
            name: authorDisplaySpecialization?.name,
            shortName: authorDisplaySpecialization?.shortName
        )
        let communityName = CommunityLabelText.preferredName(
            preferShortNames: preferShortNames,
            name: authorDisplayCommunity?.name,
            shortName: authorDisplayCommunity?.shortName
        )
        if let communityName {
            return "\(specializationName ?? "Member") @ \(communityName)"
        }
        if let specializationName {
            return specializationName
        }
        return nil
    }

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

struct RepostBannerUser: Codable, Identifiable, Hashable {
    let userId: Int
    let username: String

    var id: Int { userId }

    init(userId: Int, username: String) {
        self.userId = userId
        self.username = username
    }

    init(dto: RepostedByUserDTO) {
        self.userId = dto.userId
        self.username = dto.username
    }
}
