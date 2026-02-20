import Foundation
import Security

struct WidgetSnapshotValue: Codable, Equatable {
    struct RecentChat: Codable, Equatable, Identifiable {
        let conversationId: Int
        let title: String
        let avatarThumbnailUrl: String?
        let lastMessagePreview: String
        let unreadCount: Int

        var id: Int { conversationId }

        init(
            conversationId: Int,
            title: String,
            avatarThumbnailUrl: String?,
            lastMessagePreview: String,
            unreadCount: Int
        ) {
            self.conversationId = conversationId
            self.title = title
            self.avatarThumbnailUrl = avatarThumbnailUrl
            self.lastMessagePreview = lastMessagePreview
            self.unreadCount = unreadCount
        }

        private enum CodingKeys: String, CodingKey {
            case conversationId
            case title
            case avatarThumbnailUrl
            case lastMessagePreview
            case unreadCount
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            conversationId = max(0, try container.decodeIfPresent(Int.self, forKey: .conversationId) ?? 0)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
            avatarThumbnailUrl = try container.decodeIfPresent(String.self, forKey: .avatarThumbnailUrl)
            lastMessagePreview = try container.decodeIfPresent(String.self, forKey: .lastMessagePreview) ?? ""
            unreadCount = max(0, try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0)
        }
    }

    struct TrendingPost: Codable, Equatable {
        let postId: Int
        let communityName: String
        let contentPreview: String
        let likeCount: Int
        let commentCount: Int
        let mediaThumbnailUrl: String?

        init(
            postId: Int,
            communityName: String,
            contentPreview: String,
            likeCount: Int,
            commentCount: Int,
            mediaThumbnailUrl: String?
        ) {
            self.postId = postId
            self.communityName = communityName
            self.contentPreview = contentPreview
            self.likeCount = likeCount
            self.commentCount = commentCount
            self.mediaThumbnailUrl = mediaThumbnailUrl
        }

        private enum CodingKeys: String, CodingKey {
            case postId
            case communityName
            case contentPreview
            case likeCount
            case commentCount
            case mediaThumbnailUrl
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            postId = max(0, try container.decodeIfPresent(Int.self, forKey: .postId) ?? 0)
            communityName = try container.decodeIfPresent(String.self, forKey: .communityName) ?? ""
            contentPreview = try container.decodeIfPresent(String.self, forKey: .contentPreview) ?? ""
            likeCount = max(0, try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0)
            commentCount = max(0, try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0)
            mediaThumbnailUrl = try container.decodeIfPresent(String.self, forKey: .mediaThumbnailUrl)
        }
    }

    struct ProfileStats: Codable, Equatable {
        let followers: Int
        let following: Int
        let likesReceived: Int

        init(followers: Int = 0, following: Int = 0, likesReceived: Int = 0) {
            self.followers = followers
            self.following = following
            self.likesReceived = likesReceived
        }

        private enum CodingKeys: String, CodingKey {
            case followers
            case following
            case likesReceived
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            followers = try container.decodeIfPresent(Int.self, forKey: .followers) ?? 0
            following = try container.decodeIfPresent(Int.self, forKey: .following) ?? 0
            likesReceived = try container.decodeIfPresent(Int.self, forKey: .likesReceived) ?? 0
        }
    }

    struct ProfileSummary: Codable, Equatable {
        let displayName: String
        let avatarThumbnailUrl: String?
        let specialization: String?
        let primaryCommunityName: String?

        init(
            displayName: String = "",
            avatarThumbnailUrl: String? = nil,
            specialization: String? = nil,
            primaryCommunityName: String? = nil
        ) {
            self.displayName = displayName
            self.avatarThumbnailUrl = avatarThumbnailUrl
            self.specialization = specialization
            self.primaryCommunityName = primaryCommunityName
        }

        private enum CodingKeys: String, CodingKey {
            case displayName
            case avatarThumbnailUrl
            case specialization
            case primaryCommunityName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
            avatarThumbnailUrl = try container.decodeIfPresent(String.self, forKey: .avatarThumbnailUrl)
            specialization = try container.decodeIfPresent(String.self, forKey: .specialization)
            primaryCommunityName = try container.decodeIfPresent(String.self, forKey: .primaryCommunityName)
        }
    }

    struct VerifiedCommunity: Codable, Equatable, Identifiable, Hashable {
        let id: Int
        let name: String
        let shortName: String?
        let memberCount: Int
        let newActivityCount: Int

        init(id: Int, name: String, shortName: String?, memberCount: Int, newActivityCount: Int = 0) {
            self.id = id
            self.name = name
            self.shortName = shortName
            self.memberCount = memberCount
            self.newActivityCount = newActivityCount
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case shortName
            case memberCount
            case newActivityCount
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            shortName = try container.decodeIfPresent(String.self, forKey: .shortName)
            memberCount = try container.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
            newActivityCount = try container.decodeIfPresent(Int.self, forKey: .newActivityCount) ?? 0
        }
    }

    let updatedAt: Date
    let serverTime: Date?
    let snapshotTTLSeconds: Int
    let unreadMessageCount: Int
    let messageRequestCount: Int
    let unreadMentionCount: Int
    let profileStats: ProfileStats
    let profileSummary: ProfileSummary?
    let recentChats: [RecentChat]
    let trendingPost: TrendingPost?
    let verifiedCommunities: [VerifiedCommunity]
    let selectedCommunityId: Int?

    static let empty = WidgetSnapshotValue(
        updatedAt: .distantPast,
        serverTime: nil,
        snapshotTTLSeconds: 900,
        unreadMessageCount: 0,
        messageRequestCount: 0,
        unreadMentionCount: 0,
        profileStats: .init(),
        profileSummary: nil,
        recentChats: [],
        trendingPost: nil,
        verifiedCommunities: [],
        selectedCommunityId: nil
    )

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case serverTime
        case snapshotTTLSeconds
        case unreadMessageCount
        case messageRequestCount
        case unreadMentionCount
        case profileStats
        case profileSummary
        case recentChats
        case trendingPost
        case verifiedCommunities
        case selectedCommunityId
    }

    init(
        updatedAt: Date,
        serverTime: Date?,
        snapshotTTLSeconds: Int,
        unreadMessageCount: Int,
        messageRequestCount: Int,
        unreadMentionCount: Int,
        profileStats: ProfileStats,
        profileSummary: ProfileSummary? = nil,
        recentChats: [RecentChat] = [],
        trendingPost: TrendingPost?,
        verifiedCommunities: [VerifiedCommunity],
        selectedCommunityId: Int?
    ) {
        self.updatedAt = updatedAt
        self.serverTime = serverTime
        self.snapshotTTLSeconds = snapshotTTLSeconds
        self.unreadMessageCount = unreadMessageCount
        self.messageRequestCount = messageRequestCount
        self.unreadMentionCount = unreadMentionCount
        self.profileStats = profileStats
        self.profileSummary = profileSummary
        self.recentChats = recentChats
        self.trendingPost = trendingPost
        self.verifiedCommunities = verifiedCommunities
        self.selectedCommunityId = selectedCommunityId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        serverTime = try container.decodeIfPresent(Date.self, forKey: .serverTime)
        snapshotTTLSeconds = max(300, try container.decodeIfPresent(Int.self, forKey: .snapshotTTLSeconds) ?? 900)
        unreadMessageCount = try container.decodeIfPresent(Int.self, forKey: .unreadMessageCount) ?? 0
        messageRequestCount = try container.decodeIfPresent(Int.self, forKey: .messageRequestCount) ?? 0
        unreadMentionCount = try container.decodeIfPresent(Int.self, forKey: .unreadMentionCount) ?? 0
        profileStats = try container.decodeIfPresent(ProfileStats.self, forKey: .profileStats) ?? .init()
        profileSummary = try container.decodeIfPresent(ProfileSummary.self, forKey: .profileSummary)
        recentChats = try container.decodeIfPresent([RecentChat].self, forKey: .recentChats) ?? []
        trendingPost = try container.decodeIfPresent(TrendingPost.self, forKey: .trendingPost)
        verifiedCommunities = try container.decodeIfPresent([VerifiedCommunity].self, forKey: .verifiedCommunities) ?? []
        selectedCommunityId = try container.decodeIfPresent(Int.self, forKey: .selectedCommunityId)
    }
}

enum WidgetSnapshotRepository {
    static let snapshotKey = "widget.snapshot.v1"
    static let sharedTokenKey = "looped.auth.token.shared"
    private static let keychainTokenKey = "looped.auth.token"

    static func load() -> WidgetSnapshotValue {
        guard let data = sharedDefaults().data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshotValue.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshotValue) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults().set(data, forKey: snapshotKey)
    }

    static func authToken() -> String? {
        if let shared = sharedDefaults().string(forKey: sharedTokenKey), !shared.isEmpty {
            return shared
        }
        return getFromKeychain(key: keychainTokenKey)
    }

    static func apiBaseURL() -> URL {
        guard let bundleId = Bundle.main.bundleIdentifier?.lowercased() else {
            return URL(string: "https://api.mylooped.app")!
        }
        if bundleId.contains(".staging.") || bundleId.contains(".stagingwidgets") || bundleId.contains(".staging.widgets") {
            return URL(string: "https://api-staging.mylooped.app")!
        }
        return URL(string: "https://api.mylooped.app")!
    }

    private static func sharedDefaults() -> UserDefaults {
        guard let suiteName = appGroupSuiteName(),
              let defaults = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        return defaults
    }

    private static func appGroupSuiteName() -> String? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        let normalized = normalizeAppBundleId(bundleId)
        guard !normalized.isEmpty else { return nil }
        return "group.\(normalized)"
    }

    private static func normalizeAppBundleId(_ bundleId: String) -> String {
        if bundleId.hasSuffix(".widgets") {
            return String(bundleId.dropLast(".widgets".count))
        }
        return bundleId
    }

    private static func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }
}

enum WidgetDeepLink {
    static let home = URL(string: "looped://home")!
    static let messages = URL(string: "looped://messages")!
    static let search = URL(string: "looped://search")!
    static let profile = URL(string: "looped://profile")!
    static let createPost = URL(string: "looped://create-post")!

    static func community(_ id: Int) -> URL {
        URL(string: "looped://community/\(id)") ?? home
    }

    static func post(_ id: Int) -> URL {
        URL(string: "looped://post/\(id)") ?? home
    }

    static func conversation(_ id: Int) -> URL {
        URL(string: "looped://conversations/\(id)") ?? messages
    }
}
