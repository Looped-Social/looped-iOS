import Foundation

enum TelemetryEventType: String, Codable, Sendable {
    case feedImpression = "feed_impression"
    case postOpen = "post_open"
    case commentsOpen = "comments_open"
    case videoWatch = "video_watch"
    case interactionBlocked = "interaction_blocked"
    case communityJoinIntent = "community_join_intent"
    case communityVerifyIntent = "community_verify_intent"
    case milestoneFirstPostSheetShown = "milestone.first_post.sheet_shown"
    case milestoneFirstPostDismissed = "milestone.first_post.dismissed"
    case milestoneFirstPostShareAttempted = "milestone.first_post.share_attempted"
    case milestoneFirstPostShareCompleted = "milestone.first_post.share_completed"
}

enum TelemetryInteractionAction: String, Codable, Sendable {
    case like
    case comment
    case reply
    case vote
}

enum TelemetryValue: Codable, Sendable {
    case int(Int)
    case int64(Int64)
    case bool(Bool)
    case string(String)
    case double(Double)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        if let int64Value = try? container.decode(Int64.self) {
            self = .int64(int64Value)
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported telemetry primitive value"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .int64(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct TelemetryFeedContext: Codable, Sendable {
    let mode: String?
    let communityId: Int64?
    let requestId: UUID?
    let position: Int?

    enum CodingKeys: String, CodingKey {
        case mode
        case communityId = "community_id"
        case requestId = "request_id"
        case position
    }

    init(
        mode: String?,
        communityId: Int64?,
        requestId: UUID?,
        position: Int?
    ) {
        self.mode = mode
        self.communityId = communityId
        self.requestId = requestId
        self.position = position
    }
}

struct TelemetryEvent: Codable, Sendable {
    let eventId: UUID
    let type: String
    let occurredAtMs: Int64
    let postId: Int64?
    let commentId: Int64?
    let communityId: Int64?
    let feed: TelemetryFeedContext?
    let data: [String: TelemetryValue]?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case type
        case occurredAtMs = "occurred_at_ms"
        case postId = "post_id"
        case commentId = "comment_id"
        case communityId = "community_id"
        case feed
        case data
    }

    init(
        eventId: UUID = UUID(),
        type: TelemetryEventType,
        occurredAtMs: Int64 = TelemetryClock.nowMs,
        postId: Int64? = nil,
        commentId: Int64? = nil,
        communityId: Int64? = nil,
        feed: TelemetryFeedContext? = nil,
        data: [String: TelemetryValue]? = nil
    ) {
        self.eventId = eventId
        self.type = type.rawValue
        self.occurredAtMs = occurredAtMs
        self.postId = postId
        self.commentId = commentId
        self.communityId = communityId
        self.feed = feed
        self.data = data
    }
}

struct TelemetryBatchRequest: Codable, Sendable {
    let sessionId: UUID
    let sentAtMs: Int64?
    let events: [TelemetryEvent]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case sentAtMs = "sent_at_ms"
        case events
    }
}

struct TelemetryBatchResponse: Decodable, Sendable {
    let status: String
    let accepted: Int
    let dropped: Int
}

enum TelemetryClock {
    static var nowMs: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
