import Foundation

struct TrendingPost: Identifiable {
    let id: Int
    let imageURL: String?
    let title: String
    let subtitle: String
    let communityName: String?
    let communityShortName: String?
    let communityKind: String?

    init(
        id: Int,
        imageURL: String?,
        title: String,
        subtitle: String,
        communityName: String? = nil,
        communityShortName: String? = nil,
        communityKind: String? = nil
    ) {
        self.id = id
        self.imageURL = imageURL
        self.title = title
        self.subtitle = subtitle
        self.communityName = communityName
        self.communityShortName = communityShortName
        self.communityKind = communityKind
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
        let trimmedTitle = dto.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallbackTitle = TrendingPost.snippet(from: dto.content)
        let title = trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle
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
            subtitle: subtitle,
            communityName: dto.communityName,
            communityShortName: dto.communityShortName,
            communityKind: dto.communityKind
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
    let id: UUID
    let backendId: Int?
    let content: String
    let authorName: String
    let timestamp: Date
    let reactionCount: Int

    init(
        id: UUID = UUID(),
        backendId: Int? = nil,
        content: String,
        authorName: String,
        timestamp: Date,
        reactionCount: Int
    ) {
        self.id = id
        self.backendId = backendId
        self.content = content
        self.authorName = authorName
        self.timestamp = timestamp
        self.reactionCount = reactionCount
    }
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
    let imageUrl: String?

    init(
        id: UUID = UUID(),
        backendId: Int? = nil,
        name: String,
        shortName: String? = nil,
        description: String,
        kind: CommunityKind = .unknown,
        specializationType: CommunitySpecializationType = .unknown,
        memberCount: Int,
        imageUrl: String? = nil
    ) {
        self.id = id
        self.backendId = backendId
        self.name = name
        self.shortName = shortName
        self.description = description
        self.kind = kind
        self.specializationType = specializationType
        self.memberCount = memberCount
        self.imageUrl = imageUrl
    }

    var specializationLabel: String? {
        guard kind == .specialization else { return nil }
        return specializationType.displayName
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
