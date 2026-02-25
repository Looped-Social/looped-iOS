import Foundation

enum PeopleRecommendationSurface: String, CaseIterable, Sendable {
    case search
    case onboarding
    case feedCard = "feed_card"
    case profileSimilar = "profile_similar"
    case inboxEmpty = "inbox_empty"
}

enum PeopleRecommendationRail: String, CaseIterable, Identifiable, Sendable {
    case pymk
    case community
    case activeCommunity = "active_community"

    var id: String { rawValue }
}

struct PeopleRecommendationCommunity: Equatable, Sendable {
    let id: Int
    let name: String
}

struct PeopleRecommendationExperiment: Equatable, Sendable {
    let key: String
    let bucket: String
}

struct PeopleRecommendationReason: Equatable, Sendable {
    let code: String
    let text: String
}

struct PeopleRecommendationActions: Equatable, Sendable {
    let canConnect: Bool
    let canHide: Bool
    let canLessLikeThis: Bool
}

struct PeopleRecommendationTracking: Equatable, Sendable {
    let token: String
    let position: Int
}

struct PeopleRecommendationUser: Identifiable, Equatable, Sendable {
    let id: Int
    let handle: String
    let displayName: String
    let avatarURL: String?
    let headline: String?
    let community: PeopleRecommendationCommunity?
}

struct PeopleRecommendationItem: Identifiable, Equatable, Sendable {
    let recommendationId: String
    let user: PeopleRecommendationUser
    let reasons: [PeopleRecommendationReason]
    let actions: PeopleRecommendationActions
    let tracking: PeopleRecommendationTracking

    var id: String { recommendationId }
}

struct PeopleRecommendationRailPage: Equatable, Sendable {
    let requestId: String
    let rail: PeopleRecommendationRail
    let title: String
    var items: [PeopleRecommendationItem]
    let nextCursor: String?
    let hasMore: Bool
    let degraded: Bool
    let community: PeopleRecommendationCommunity?
    let experiment: PeopleRecommendationExperiment?
}

struct PeopleRecommendationRailsBundle: Equatable, Sendable {
    let requestId: String
    let surface: PeopleRecommendationSurface
    let community: PeopleRecommendationCommunity?
    let rails: [PeopleRecommendationRailPage]
    let experiment: PeopleRecommendationExperiment?
    let degraded: Bool
    let generatedAt: Date
}

enum PeopleRecommendationFeedbackType: String, Codable, Sendable {
    case impression
    case profileOpen = "profile_open"
    case connectRequestSent = "connect_request_sent"
    case connectAccepted = "connect_accepted"
    case hide
    case lessLikeThis = "less_like_this"
}

struct PeopleRecommendationFeedbackEvent: Encodable, Sendable {
    let eventId: String
    let type: PeopleRecommendationFeedbackType
    let recommendationId: String
    let trackingToken: String
    let position: Int
    let clientTs: String
    let metadata: [String: TelemetryValue]?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case type
        case recommendationId = "recommendation_id"
        case trackingToken = "tracking_token"
        case position
        case clientTs = "client_ts"
        case metadata
    }

    init(
        eventId: String = UUID().uuidString,
        type: PeopleRecommendationFeedbackType,
        recommendationId: String,
        trackingToken: String,
        position: Int,
        clientDate: Date = Date(),
        metadata: [String: TelemetryValue]? = nil
    ) {
        self.eventId = eventId
        self.type = type
        self.recommendationId = recommendationId
        self.trackingToken = trackingToken
        self.position = position
        self.clientTs = Self.timestampFormatter.string(from: clientDate)
        self.metadata = metadata
    }
}

struct PeopleRecommendationFeedbackResponse: Decodable, Equatable, Sendable {
    let requestId: String
    let accepted: Int
    let deduped: Int
    let dropped: Int
    let suppressedCandidateIds: [Int]
}

private extension PeopleRecommendationFeedbackEvent {
    static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
