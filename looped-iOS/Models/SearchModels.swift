import Foundation

struct TrendingPost: Identifiable {
    let id: Int
    let imageURL: String?
    let title: String
    let contentPreview: String?
    let subtitle: String
    let authorDisplayName: String?
    let authorProfileImageURL: String?
    let isAnonymous: Bool
    let communityName: String?
    let communityShortName: String?
    let communityKind: String?
    let mediaAssetIds: [Int]?

    init(
        id: Int,
        imageURL: String?,
        title: String,
        contentPreview: String? = nil,
        subtitle: String,
        authorDisplayName: String? = nil,
        authorProfileImageURL: String? = nil,
        isAnonymous: Bool = false,
        communityName: String? = nil,
        communityShortName: String? = nil,
        communityKind: String? = nil,
        mediaAssetIds: [Int]? = nil
    ) {
        self.id = id
        self.imageURL = imageURL
        self.title = title
        self.contentPreview = contentPreview
        self.subtitle = subtitle
        self.authorDisplayName = authorDisplayName
        self.authorProfileImageURL = authorProfileImageURL
        self.isAnonymous = isAnonymous
        self.communityName = communityName
        self.communityShortName = communityShortName
        self.communityKind = communityKind
        self.mediaAssetIds = mediaAssetIds
    }

    func subtitleText(preferShortNames: Bool) -> String {
        if let label = CommunityLabelText.preferredName(
            preferShortNames: preferShortNames,
            name: communityName,
            shortName: communityShortName
        ) {
            return "Trending in \(label)"
        }
        if let kind = communityKind?.trimmedNonEmpty {
            return "Trending in \(kind.capitalized)"
        }
        return subtitle
    }
}

extension TrendingPost {
    init(dto: TrendingPostDTO) {
        let resolvedMediaAssetIds: [Int]? = {
            let camel = (dto.mediaAssetIds ?? []).filter { $0 > 0 }
            if !camel.isEmpty { return camel }
            let snake = (dto.mediaAssetIdsSnake ?? []).filter { $0 > 0 }
            if !snake.isEmpty { return snake }
            if let single = dto.mediaAssetId, single > 0 { return [single] }
            return nil
        }()
        let trimmedTitle = dto.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let contentSnippet = TrendingPost.snippet(from: dto.content)
        let fallbackTitle = contentSnippet
        let title = trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle
        let contentPreview: String? = {
            guard !contentSnippet.isEmpty else { return nil }
            return trimmedTitle.isEmpty ? nil : contentSnippet
        }()
        let authorDisplayName: String? = {
            if dto.isAnonymous == true || dto.authorIsAnonymous == true {
                return "Anonymous"
            }
            let trimmedName = dto.authorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedName.isEmpty { return trimmedName }
            let first = dto.authorFirstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let last = dto.authorLastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let joined = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { return joined }
            let handle = dto.authorHandle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !handle.isEmpty { return handle }
            return nil
        }()
        let subtitle: String = {
            if let label = CommunityLabelText.preferredName(
                preferShortNames: false,
                name: dto.communityName,
                shortName: dto.communityShortName
            ) {
                return "Trending in \(label)"
            }
            if let kind = dto.communityKind?.trimmedNonEmpty {
                return "Trending in \(kind.capitalized)"
            }
            return "Trending on Looped"
        }()

        self.init(
            id: dto.id,
            imageURL: dto.cdnUrl ?? dto.mediaUrl,
            title: title,
            contentPreview: contentPreview,
            subtitle: subtitle,
            authorDisplayName: authorDisplayName,
            authorProfileImageURL: dto.authorProfileImageUrl,
            isAnonymous: dto.isAnonymous == true || dto.authorIsAnonymous == true,
            communityName: dto.communityName,
            communityShortName: dto.communityShortName,
            communityKind: dto.communityKind,
            mediaAssetIds: resolvedMediaAssetIds
        )
    }

    private static func snippet(from content: String) -> String {
        let collapsed = content.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 80 {
            return String(trimmed.prefix(80)) + "..."
        }
        return trimmed
    }
}

extension TrendingPost {
    func updating(imageURL: String?) -> TrendingPost {
        TrendingPost(
            id: id,
            imageURL: imageURL,
            title: title,
            contentPreview: contentPreview,
            subtitle: subtitle,
            authorDisplayName: authorDisplayName,
            authorProfileImageURL: authorProfileImageURL,
            isAnonymous: isAnonymous,
            communityName: communityName,
            communityShortName: communityShortName,
            communityKind: communityKind,
            mediaAssetIds: mediaAssetIds
        )
    }
}

struct LoopCategory: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let memberCount: Int

    init(id: UUID = UUID(), title: String, description: String, memberCount: Int) {
        self.id = id
        self.title = title
        self.description = description
        self.memberCount = memberCount
    }
}

struct SearchGroup: Identifiable {
    let id: UUID
    let title: String
    let iconName: String
    let memberCount: Int

    init(id: UUID = UUID(), title: String, iconName: String, memberCount: Int) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.memberCount = memberCount
    }
}

struct SearchFilterOption: Identifiable, Equatable {
    let id: UUID
    let title: String
    let apiKey: String

    init(id: UUID = UUID(), title: String, apiKey: String) {
        self.id = id
        self.title = title
        self.apiKey = apiKey
    }
}

struct SearchResultPerson: Identifiable {
    let id: UUID
    let backendId: Int?
    let name: String
    let username: String
    let title: String
    let company: String
    let avatarURL: String?

    init(
        id: UUID = UUID(),
        backendId: Int? = nil,
        name: String,
        username: String,
        title: String,
        company: String,
        avatarURL: String?
    ) {
        self.id = id
        self.backendId = backendId
        self.name = name
        self.username = username
        self.title = title
        self.company = company
        self.avatarURL = avatarURL
    }
}

struct SearchResultPost: Identifiable {
    let post: Post

    var id: UUID { post.id }
    var backendId: Int? { post.backendId }
}

struct SearchResultLoop: Identifiable {
    let id: UUID
    let backendId: Int?
    let name: String
    let shortName: String?
    let description: String
    let kind: CommunityKind
    let specializationType: CommunitySpecializationType
    let memberCount: Int
    let bannerImageUrl: String?
    let profileImageUrl: String?
    let imageUrl: String?
    let icon: CommunityIcon?

    init(
        id: UUID = UUID(),
        backendId: Int? = nil,
        name: String,
        shortName: String? = nil,
        description: String,
        kind: CommunityKind = .unknown,
        specializationType: CommunitySpecializationType = .unknown,
        memberCount: Int,
        bannerImageUrl: String? = nil,
        profileImageUrl: String? = nil,
        imageUrl: String? = nil,
        icon: CommunityIcon? = nil
    ) {
        self.id = id
        self.backendId = backendId
        self.name = name
        self.shortName = shortName
        self.description = description
        self.kind = kind
        self.specializationType = specializationType
        self.memberCount = memberCount
        self.bannerImageUrl = bannerImageUrl
        self.profileImageUrl = profileImageUrl
        self.imageUrl = imageUrl
        self.icon = icon
    }

    var specializationLabel: String? {
        guard kind == .specialization else { return nil }
        return specializationType.displayName
    }

    var bannerDisplayImageUrl: String? {
        bannerImageUrl?.trimmedNonEmpty ?? imageUrl?.trimmedNonEmpty
    }

    var profileDisplayImageUrl: String? {
        profileImageUrl?.trimmedNonEmpty ?? imageUrl?.trimmedNonEmpty
    }
}

struct SearchResultHashtag: Identifiable {
    let id: UUID
    let name: String
    let usageCount: Int

    init(id: UUID = UUID(), name: String, usageCount: Int) {
        self.id = id
        self.name = name
        self.usageCount = usageCount
    }
}
