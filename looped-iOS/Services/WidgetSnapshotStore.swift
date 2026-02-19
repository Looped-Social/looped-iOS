import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetSnapshot: Codable, Equatable {
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

    struct VerifiedCommunity: Codable, Equatable, Identifiable {
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
    let trendingPost: TrendingPost?
    let verifiedCommunities: [VerifiedCommunity]
    let selectedCommunityId: Int?

    static let empty = WidgetSnapshot(
        updatedAt: .distantPast,
        serverTime: nil,
        snapshotTTLSeconds: 900,
        unreadMessageCount: 0,
        messageRequestCount: 0,
        unreadMentionCount: 0,
        profileStats: .init(followers: 0, following: 0, likesReceived: 0),
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
        trendingPost = try container.decodeIfPresent(TrendingPost.self, forKey: .trendingPost)
        verifiedCommunities = try container.decodeIfPresent([VerifiedCommunity].self, forKey: .verifiedCommunities) ?? []
        selectedCommunityId = try container.decodeIfPresent(Int.self, forKey: .selectedCommunityId)
    }
}

enum WidgetSnapshotStore {
    static let snapshotKey = "widget.snapshot.v1"

    static func save(
        unreadMessageCount: Int,
        messageRequestCount: Int,
        unreadMentionCount: Int,
        verifiedCommunities: [CommunitySummary],
        selectedCommunityId: Int?,
        trendingPost: WidgetSnapshot.TrendingPost? = nil
    ) {
        let previous = load()
        let previousCommunityActivity = Dictionary(uniqueKeysWithValues: previous.verifiedCommunities.map { ($0.id, $0.newActivityCount) })
        let mergedCommunities: [WidgetSnapshot.VerifiedCommunity] = {
            guard !verifiedCommunities.isEmpty else { return previous.verifiedCommunities }
            return verifiedCommunities.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    shortName: $0.shortName,
                    memberCount: $0.memberCount,
                    newActivityCount: previousCommunityActivity[$0.id] ?? 0
                )
            }
        }()
        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            serverTime: previous.serverTime,
            snapshotTTLSeconds: previous.snapshotTTLSeconds,
            unreadMessageCount: max(0, unreadMessageCount),
            messageRequestCount: max(0, messageRequestCount),
            unreadMentionCount: max(0, unreadMentionCount),
            profileStats: previous.profileStats,
            trendingPost: trendingPost ?? previous.trendingPost,
            verifiedCommunities: mergedCommunities,
            selectedCommunityId: selectedCommunityId
                ?? previous.selectedCommunityId
                ?? mergedCommunities.first?.id
        )

        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults().set(encoded, forKey: snapshotKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func load() -> WidgetSnapshot {
        guard let data = sharedDefaults().data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults().set(encoded, forKey: snapshotKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static func sharedDefaults() -> UserDefaults {
        if let suiteName = appGroupSuiteName(),
           let defaults = UserDefaults(suiteName: suiteName) {
            return defaults
        }
        return .standard
    }

    private static func appGroupSuiteName() -> String? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        let normalized = normalizeAppBundleId(bundleId)
        return normalized.isEmpty ? nil : "group.\(normalized)"
    }

    private static func normalizeAppBundleId(_ bundleId: String) -> String {
        if bundleId.hasSuffix(".widgets") {
            return String(bundleId.dropLast(".widgets".count))
        }
        return bundleId
    }
}
