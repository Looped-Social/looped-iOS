import Foundation

struct WidgetSummaryDTO: Decodable {
    struct InboxDTO: Decodable {
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

    struct ProfileStatsDTO: Decodable {
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

    struct VerifiedCommunityDTO: Decodable {
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

    struct TrendingPostDTO: Decodable {
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

    let serverTime: Date?
    let snapshotTtlSeconds: Int?
    let inbox: InboxDTO
    let profileStats: ProfileStatsDTO
    let trendingPost: TrendingPostDTO?
    let verifiedCommunities: [VerifiedCommunityDTO]
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
        inbox = try container.decodeIfPresent(InboxDTO.self, forKey: .inbox) ?? .init()
        profileStats = try container.decodeIfPresent(ProfileStatsDTO.self, forKey: .profileStats) ?? .init()
        trendingPost = try container.decodeIfPresent(TrendingPostDTO.self, forKey: .trendingPost)
        verifiedCommunities = try container.decodeIfPresent([VerifiedCommunityDTO].self, forKey: .verifiedCommunities) ?? []
        defaultCommunityId = try container.decodeIfPresent(Int.self, forKey: .defaultCommunityId)
    }
}

struct WidgetSeenResponseDTO: Decodable {
    let communityId: Int
    let seenAt: Date?
}

private enum WidgetSummaryServiceError: Error {
    case unauthorized
    case forbidden
    case notFound
    case userNotProvisioned
    case rateLimited
    case invalidResponse
    case serverError(Int)
}

enum WidgetSummaryService {
    static func latestSnapshot() async -> WidgetSnapshotValue {
        let cached = WidgetSnapshotRepository.load()
        guard let token = WidgetSnapshotRepository.authToken(), !token.isEmpty else {
            return cached
        }

        do {
            let dto = try await fetchSummary(token: token)
            let mapped = map(dto: dto, previous: cached)
            WidgetSnapshotRepository.save(mapped)
            return mapped
        } catch {
            return cached
        }
    }

    static func markCommunitySeen(_ communityId: Int) async {
        guard communityId > 0 else { return }
        guard let token = WidgetSnapshotRepository.authToken(), !token.isEmpty else { return }
        _ = try? await postSeen(communityId: communityId, token: token)
    }

    private static func fetchSummary(token: String) async throws -> WidgetSummaryDTO {
        let baseURL = WidgetSnapshotRepository.apiBaseURL()
        let url = baseURL.appendingPathComponent("v1").appendingPathComponent("widget-summary")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try requireHTTP(response)
        try validateStatus(http.statusCode)

        let decoder = makeDecoder()
        return try decoder.decode(WidgetSummaryDTO.self, from: data)
    }

    private static func postSeen(communityId: Int, token: String) async throws -> WidgetSeenResponseDTO {
        let baseURL = WidgetSnapshotRepository.apiBaseURL()
        let url = baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("widget-state")
            .appendingPathComponent("community")
            .appendingPathComponent(String(communityId))
            .appendingPathComponent("seen")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try requireHTTP(response)
        try validateStatus(http.statusCode)

        let decoder = makeDecoder()
        return try decoder.decode(WidgetSeenResponseDTO.self, from: data)
    }

    private static func requireHTTP(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw WidgetSummaryServiceError.invalidResponse
        }
        return http
    }

    private static func validateStatus(_ statusCode: Int) throws {
        switch statusCode {
        case 200 ..< 300:
            return
        case 401:
            throw WidgetSummaryServiceError.unauthorized
        case 403:
            throw WidgetSummaryServiceError.forbidden
        case 404:
            throw WidgetSummaryServiceError.notFound
        case 409:
            throw WidgetSummaryServiceError.userNotProvisioned
        case 429:
            throw WidgetSummaryServiceError.rateLimited
        default:
            throw WidgetSummaryServiceError.serverError(statusCode)
        }
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ISO8601DateFormatter.withFractional.date(from: raw) {
                return date
            }
            if let date = ISO8601DateFormatter.withoutFractional.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }
        return decoder
    }

    private static func map(dto: WidgetSummaryDTO, previous: WidgetSnapshotValue) -> WidgetSnapshotValue {
        let communities = dto.verifiedCommunities.map {
            WidgetSnapshotValue.VerifiedCommunity(
                id: $0.id,
                name: $0.name,
                shortName: $0.shortName,
                memberCount: max(0, $0.memberCount),
                newActivityCount: max(0, $0.newActivityCount)
            )
        }

        let selectedCommunityId: Int? = {
            if let defaultId = dto.defaultCommunityId, communities.contains(where: { $0.id == defaultId }) {
                return defaultId
            }
            if let existingId = previous.selectedCommunityId, communities.contains(where: { $0.id == existingId }) {
                return existingId
            }
            return communities.first?.id
        }()

        return WidgetSnapshotValue(
            updatedAt: .now,
            serverTime: dto.serverTime,
            snapshotTTLSeconds: max(300, dto.snapshotTtlSeconds ?? 900),
            unreadMessageCount: max(0, dto.inbox.unreadMessages),
            messageRequestCount: max(0, dto.inbox.messageRequests),
            unreadMentionCount: max(0, dto.inbox.unreadMentions),
            profileStats: .init(
                followers: max(0, dto.profileStats.followers),
                following: max(0, dto.profileStats.following),
                likesReceived: max(0, dto.profileStats.likesReceived)
            ),
            trendingPost: dto.trendingPost.flatMap { post in
                guard post.postId > 0 else { return nil }
                let preview = post.contentPreview.trimmingCharacters(in: .whitespacesAndNewlines)
                let community = post.communityName.trimmingCharacters(in: .whitespacesAndNewlines)
                return .init(
                    postId: post.postId,
                    communityName: community.isEmpty ? "Trending" : community,
                    contentPreview: preview.isEmpty ? "Open Looped to see what's trending." : preview,
                    likeCount: max(0, post.likeCount),
                    commentCount: max(0, post.commentCount),
                    mediaThumbnailUrl: post.mediaThumbnailUrl
                )
            } ?? previous.trendingPost,
            verifiedCommunities: communities,
            selectedCommunityId: selectedCommunityId
        )
    }
}

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let withoutFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
