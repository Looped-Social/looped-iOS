import Foundation

protocol WidgetSummaryServiceProtocol {
    func refreshSharedSnapshot() async
    func markCommunitySeen(communityId: Int) async
}

struct WidgetSummaryService: WidgetSummaryServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func refreshSharedSnapshot() async {
        let previous = WidgetSnapshotStore.load()
        do {
            let response: WidgetSummaryResponse = try await apiClient.get("v1/widget-summary")
            let snapshot = WidgetSnapshot(
                updatedAt: Date(),
                serverTime: response.serverTime,
                snapshotTTLSeconds: max(300, response.snapshotTtlSeconds ?? 900),
                unreadMessageCount: max(0, response.inbox.unreadMessages),
                messageRequestCount: max(0, response.inbox.messageRequests),
                unreadMentionCount: max(0, response.inbox.unreadMentions),
                profileStats: .init(
                    followers: max(0, response.profileStats.followers),
                    following: max(0, response.profileStats.following),
                    likesReceived: max(0, response.profileStats.likesReceived)
                ),
                trendingPost: response.trendingPost.flatMap { dto in
                    guard dto.postId > 0 else { return nil }
                    let preview = dto.contentPreview.trimmingCharacters(in: .whitespacesAndNewlines)
                    let communityName = dto.communityName.trimmingCharacters(in: .whitespacesAndNewlines)
                    return .init(
                        postId: dto.postId,
                        communityName: communityName.isEmpty ? "Trending" : communityName,
                        contentPreview: preview.isEmpty ? "Open Looped to view this trending post." : preview,
                        likeCount: max(0, dto.likeCount),
                        commentCount: max(0, dto.commentCount),
                        mediaThumbnailUrl: dto.mediaThumbnailUrl
                    )
                } ?? previous.trendingPost,
                verifiedCommunities: response.verifiedCommunities.map {
                    .init(
                        id: $0.id,
                        name: $0.name,
                        shortName: $0.shortName,
                        memberCount: max(0, $0.memberCount),
                        newActivityCount: max(0, $0.newActivityCount)
                    )
                },
                selectedCommunityId: response.defaultCommunityId
            )
            WidgetSnapshotStore.save(snapshot)
        } catch {
            // Best effort: keep previous snapshot on failure.
        }
    }

    func markCommunitySeen(communityId: Int) async {
        guard communityId > 0 else { return }
        do {
            let _: WidgetCommunitySeenResponse = try await apiClient.post(
                "v1/widget-state/community/\(communityId)/seen",
                body: EmptyWidgetPayload()
            )
        } catch {
            // Best effort only.
        }
    }
}

private struct WidgetSummaryResponse: Decodable {
    let serverTime: Date?
    let snapshotTtlSeconds: Int?
    let inbox: WidgetSummaryInbox
    let profileStats: WidgetSummaryProfileStats
    let trendingPost: WidgetSummaryTrendingPost?
    let verifiedCommunities: [WidgetSummaryCommunity]
    let defaultCommunityId: Int?

    private enum CodingKeys: String, CodingKey {
        case serverTime
        case snapshotTtlSeconds
        case inbox
        case profileStats
        case trendingPost
        case verifiedCommunities
        case defaultCommunityId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serverTime = try container.decodeIfPresent(Date.self, forKey: .serverTime)
        snapshotTtlSeconds = try container.decodeIfPresent(Int.self, forKey: .snapshotTtlSeconds)
        inbox = try container.decodeIfPresent(WidgetSummaryInbox.self, forKey: .inbox) ?? .init()
        profileStats = try container.decodeIfPresent(WidgetSummaryProfileStats.self, forKey: .profileStats) ?? .init()
        trendingPost = try container.decodeIfPresent(WidgetSummaryTrendingPost.self, forKey: .trendingPost)
        verifiedCommunities = try container.decodeIfPresent([WidgetSummaryCommunity].self, forKey: .verifiedCommunities) ?? []
        defaultCommunityId = try container.decodeIfPresent(Int.self, forKey: .defaultCommunityId)
    }
}

private struct WidgetSummaryTrendingPost: Decodable {
    let postId: Int
    let communityName: String
    let contentPreview: String
    let likeCount: Int
    let commentCount: Int
    let mediaThumbnailUrl: String?

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
        postId = try container.decodeIfPresent(Int.self, forKey: .postId) ?? 0
        communityName = try container.decodeIfPresent(String.self, forKey: .communityName) ?? ""
        contentPreview = try container.decodeIfPresent(String.self, forKey: .contentPreview) ?? ""
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        mediaThumbnailUrl = try container.decodeIfPresent(String.self, forKey: .mediaThumbnailUrl)
    }
}

private struct WidgetSummaryInbox: Decodable {
    let unreadMessages: Int
    let messageRequests: Int
    let unreadMentions: Int

    init(unreadMessages: Int = 0, messageRequests: Int = 0, unreadMentions: Int = 0) {
        self.unreadMessages = unreadMessages
        self.messageRequests = messageRequests
        self.unreadMentions = unreadMentions
    }

    private enum CodingKeys: String, CodingKey {
        case unreadMessages
        case messageRequests
        case unreadMentions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unreadMessages = try container.decodeIfPresent(Int.self, forKey: .unreadMessages) ?? 0
        messageRequests = try container.decodeIfPresent(Int.self, forKey: .messageRequests) ?? 0
        unreadMentions = try container.decodeIfPresent(Int.self, forKey: .unreadMentions) ?? 0
    }
}

private struct WidgetSummaryProfileStats: Decodable {
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

private struct WidgetSummaryCommunity: Decodable {
    let id: Int
    let name: String
    let shortName: String?
    let memberCount: Int
    let newActivityCount: Int

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

private struct WidgetCommunitySeenResponse: Decodable {
    let communityId: Int
    let seenAt: Date?
}

private struct EmptyWidgetPayload: Encodable {}
