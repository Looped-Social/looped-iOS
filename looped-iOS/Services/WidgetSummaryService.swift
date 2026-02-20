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
            let fallbackTrending = await fetchTrendingFallback()
            let incomingProfileSummary: WidgetSnapshot.ProfileSummary? = {
                guard let summary = response.profileSummary else { return nil }
                let displayName = summary.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                let specialization = summary.specialization?.trimmingCharacters(in: .whitespacesAndNewlines)
                let community = summary.primaryCommunityName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let avatar = summary.avatarThumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
                if displayName.isEmpty && (specialization ?? "").isEmpty && (community ?? "").isEmpty && (avatar ?? "").isEmpty {
                    return nil
                }
                return .init(
                    displayName: displayName,
                    avatarThumbnailUrl: (avatar?.isEmpty == false) ? avatar : nil,
                    specialization: (specialization?.isEmpty == false) ? specialization : nil,
                    primaryCommunityName: (community?.isEmpty == false) ? community : nil
                )
            }()
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
                profileSummary: incomingProfileSummary ?? previous.profileSummary,
                recentChats: mapRecentChats(response.recentChats),
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
                } ?? fallbackTrending ?? previous.trendingPost,
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

    private func fetchTrendingFallback() async -> WidgetSnapshot.TrendingPost? {
        do {
            let response: WidgetTrendingFeedResponse = try await apiClient.get("v1/feed/trending?limit=1")
            guard let item = response.items.first, item.id > 0 else { return nil }
            let previewRaw = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = previewRaw.isEmpty
                ? "Open app to get the latest posts and update this widget."
                : previewRaw
            let communityRaw = (item.communityShortName ?? item.communityName ?? "Trending")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let community = communityRaw.isEmpty ? "Trending" : communityRaw
            return .init(
                postId: item.id,
                communityName: community,
                contentPreview: preview,
                likeCount: max(0, item.likesCount),
                commentCount: max(0, item.commentsCount),
                mediaThumbnailUrl: item.cdnUrl ?? item.mediaUrl
            )
        } catch {
            return nil
        }
    }

    private func mapRecentChats(_ chats: [WidgetSummaryRecentChat]) -> [WidgetSnapshot.RecentChat] {
        let mapped = chats.compactMap { chat -> WidgetSnapshot.RecentChat? in
            guard chat.conversationId > 0 else { return nil }
            let title = chat.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = chat.lastMessagePreview.trimmingCharacters(in: .whitespacesAndNewlines)
            let avatar = chat.avatarThumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(
                conversationId: chat.conversationId,
                title: title.isEmpty ? "Chat" : title,
                avatarThumbnailUrl: (avatar?.isEmpty == false) ? avatar : nil,
                lastMessagePreview: preview.isEmpty ? "Open chat to continue." : preview,
                unreadCount: max(0, chat.unreadCount)
            )
        }
        return Array(mapped.prefix(3))
    }
}

private struct WidgetTrendingFeedResponse: Decodable {
    let items: [WidgetTrendingFeedItem]
}

private struct WidgetTrendingFeedItem: Decodable {
    let id: Int
    let content: String
    let likesCount: Int
    let commentsCount: Int
    let communityName: String?
    let communityShortName: String?
    let mediaUrl: String?
    let cdnUrl: String?
}

private struct WidgetSummaryResponse: Decodable {
    let serverTime: Date?
    let snapshotTtlSeconds: Int?
    let inbox: WidgetSummaryInbox
    let profileStats: WidgetSummaryProfileStats
    let profileSummary: WidgetSummaryProfileSummary?
    let recentChats: [WidgetSummaryRecentChat]
    let trendingPost: WidgetSummaryTrendingPost?
    let verifiedCommunities: [WidgetSummaryCommunity]
    let defaultCommunityId: Int?

    private enum CodingKeys: String, CodingKey {
        case serverTime
        case snapshotTtlSeconds
        case inbox
        case profileStats
        case profileSummary
        case recentChats
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
        profileSummary = try container.decodeIfPresent(WidgetSummaryProfileSummary.self, forKey: .profileSummary)
        recentChats = try container.decodeIfPresent([WidgetSummaryRecentChat].self, forKey: .recentChats) ?? []
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

private struct WidgetSummaryProfileSummary: Decodable {
    let displayName: String
    let avatarThumbnailUrl: String?
    let specialization: String?
    let primaryCommunityName: String?

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

private struct WidgetSummaryRecentChat: Decodable {
    let conversationId: Int
    let title: String
    let avatarThumbnailUrl: String?
    let lastMessagePreview: String
    let unreadCount: Int

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
