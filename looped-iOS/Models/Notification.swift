import Foundation

// MARK: - Notification Model
struct Notification: Codable, Identifiable {
    let id: UUID
    /// Canonical UUID for analytics/dedupe (distinct from the numeric backend id used for mark-read/dismiss).
    let notificationUUID: UUID?
    let type: NotificationType
    let actorId: UUID?
    let actorAnonProfileId: UUID?
    let actorName: String
    let actorProfileImageUrl: String?
    let actorIsAnonymous: Bool
    let additionalActors: [NotificationActor]? // For grouped notifications
    let targetId: UUID? // Post/Comment/User ID that was affected
    let targetCommentId: UUID?
    let targetContent: String? // Preview of post/comment content
    let title: String?
    let body: String?
    let category: String?
    let verificationKind: String?
    let verificationStatus: String?
    let verificationMethod: String?
    let verificationCommunityId: Int?
    let verificationCommunityName: String?
    let verificationExpiresAt: Date?
    let verificationDaysRemaining: Int?
    let verificationEventKey: String?
    let verificationRejectReason: String?
    let announcementKind: NotificationAnnouncementKind?
    let announcementYears: Int?
    let deeplink: String?
    let actionDeeplink: String?
    let fallbackDeeplink: String?
    let privacyLevel: NotificationPrivacyLevel?
    let reason: JSONValue?
    let newPostsCount: Int?
    let since: Date?
    let communityId: Int?
    let mentionContext: NotificationMentionContext?
    let isRead: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        notificationUUID: UUID? = nil,
        type: NotificationType,
        actorId: UUID? = nil,
        actorAnonProfileId: UUID? = nil,
        actorName: String,
        actorProfileImageUrl: String? = nil,
        actorIsAnonymous: Bool = false,
        additionalActors: [NotificationActor]? = nil,
        targetId: UUID? = nil,
        targetCommentId: UUID? = nil,
        targetContent: String? = nil,
        title: String? = nil,
        body: String? = nil,
        category: String? = nil,
        verificationKind: String? = nil,
        verificationStatus: String? = nil,
        verificationMethod: String? = nil,
        verificationCommunityId: Int? = nil,
        verificationCommunityName: String? = nil,
        verificationExpiresAt: Date? = nil,
        verificationDaysRemaining: Int? = nil,
        verificationEventKey: String? = nil,
        verificationRejectReason: String? = nil,
        announcementKind: NotificationAnnouncementKind? = nil,
        announcementYears: Int? = nil,
        deeplink: String? = nil,
        actionDeeplink: String? = nil,
        fallbackDeeplink: String? = nil,
        privacyLevel: NotificationPrivacyLevel? = nil,
        reason: JSONValue? = nil,
        newPostsCount: Int? = nil,
        since: Date? = nil,
        communityId: Int? = nil,
        mentionContext: NotificationMentionContext? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.notificationUUID = notificationUUID
        self.type = type
        self.actorId = actorId
        self.actorAnonProfileId = actorAnonProfileId
        self.actorName = actorName
        self.actorProfileImageUrl = actorProfileImageUrl
        self.actorIsAnonymous = actorIsAnonymous
        self.additionalActors = additionalActors
        self.targetId = targetId
        self.targetCommentId = targetCommentId
        self.targetContent = targetContent
        self.title = title
        self.body = body
        self.category = category
        self.verificationKind = verificationKind
        self.verificationStatus = verificationStatus
        self.verificationMethod = verificationMethod
        self.verificationCommunityId = verificationCommunityId
        self.verificationCommunityName = verificationCommunityName
        self.verificationExpiresAt = verificationExpiresAt
        self.verificationDaysRemaining = verificationDaysRemaining
        self.verificationEventKey = verificationEventKey
        self.verificationRejectReason = verificationRejectReason
        self.announcementKind = announcementKind
        self.announcementYears = announcementYears
        self.deeplink = deeplink
        self.actionDeeplink = actionDeeplink
        self.fallbackDeeplink = fallbackDeeplink
        self.privacyLevel = privacyLevel
        self.reason = reason
        self.newPostsCount = newPostsCount
        self.since = since
        self.communityId = communityId
        self.mentionContext = mentionContext
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

// MARK: - Notification Type
enum NotificationType: String, Codable {
    case like           // Someone liked your post
    case comment        // Someone commented on your post
    case reply          // Someone replied to your comment
    case mention        // Someone mentioned you
    case follow         // Someone followed you
    case postFromFollowed = "post_from_followed"
    case messageRequest = "message_request"
    case sinceAwayHighlights = "since_away_highlights"
    case trendingToday = "trending_today"
    case announcement
    case system
    case loopInvite     // Someone invited you to a loop
    case groupInvite    // Someone added you to a group
    case repost         // Someone reposted your post
}

enum NotificationPrivacyLevel: String, Codable {
    case generic
    case detailed
}

enum NotificationMentionContext: String, Codable {
    case post
    case comment
}

enum NotificationAnnouncementKind: String, Codable {
    case birthday
    case anniversary
}

// MARK: - Additional Actor (for grouped notifications)
struct NotificationActor: Codable, Identifiable {
    let id: UUID
    let name: String
    let profileImageUrl: String?

    init(
        id: UUID = UUID(),
        name: String,
        profileImageUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.profileImageUrl = profileImageUrl
    }
}

// MARK: - Notification Extensions
extension Notification {
    /// Returns the formatted notification text
    var notificationText: String {
        let actorText = actorName

        // Handle grouped notifications
        if let additionalActors = additionalActors, !additionalActors.isEmpty {
            let othersCount = additionalActors.count
            let othersText = othersCount == 1 ? "1 other" : "\(othersCount) others"

            switch type {
            case .like:
                return "\(actorText) and \(othersText) liked your post"
            case .comment:
                return "\(actorText) and \(othersText) commented on your post"
            case .follow:
                return "\(actorText) and \(othersText) started following you"
            default:
                return "\(actorText) and \(othersText) interacted with your content"
            }
        }

        // Single actor notifications
        switch type {
        case .like:
            return "\(actorText) liked your post"
        case .comment:
            return "\(actorText) commented on your post"
        case .reply:
            return "\(actorText) replied to your comment"
        case .mention:
            if mentionContext == .comment {
                return "\(actorText) mentioned you in a comment"
            }
            return "\(actorText) mentioned you in a post"
        case .follow:
            return "\(actorText) started following you"
        case .postFromFollowed:
            return "\(actorText) shared a new post"
        case .messageRequest:
            return "\(actorText) sent you a message request"
        case .sinceAwayHighlights:
            if let title = trimmedTitle, !title.isEmpty {
                return title
            }
            return "Top posts since you were away"
        case .trendingToday:
            if let title = trimmedTitle, !title.isEmpty {
                return title
            }
            return "Trending right now"
        case .announcement:
            if isVerificationNotification {
                return resolvedVerificationTitle
            }
            if let title = trimmedTitle, !title.isEmpty {
                return "\(actorText): \(title)"
            }
            return "\(actorText) posted an announcement"
        case .system:
            if isVerificationNotification {
                return resolvedVerificationTitle
            }
            if let title = trimmedTitle, !title.isEmpty {
                return "System: \(title)"
            }
            return "System notification"
        case .loopInvite:
            return "\(actorText) invited you to join a loop"
        case .groupInvite:
            return "\(actorText) added you to a group"
        case .repost:
            return "\(actorText) reposted your post"
        }
    }

    /// Returns the relative time string (e.g., "2h", "1d", "3w")
    var relativeTimeString: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(createdAt)

        let minutes = Int(timeInterval) / 60
        let hours = Int(timeInterval) / 3600
        let days = Int(timeInterval) / 86400
        let weeks = Int(timeInterval) / 604800

        if weeks > 0 {
            return "\(weeks)w"
        } else if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }

    /// Returns SF Symbol icon name for notification type
    var iconName: String {
        switch type {
        case .like:
            return "heart.fill"
        case .comment:
            return "bubble.left.fill"
        case .reply:
            return "arrowshape.turn.up.left.fill"
        case .mention:
            return "at"
        case .follow:
            return "person.fill.badge.plus"
        case .postFromFollowed:
            return "person.2.fill"
        case .messageRequest:
            return "tray.fill"
        case .sinceAwayHighlights:
            return "sparkles"
        case .trendingToday:
            return "flame.fill"
        case .announcement:
            return "megaphone.fill"
        case .system:
            return "gearshape.fill"
        case .loopInvite:
            return "person.2.fill"
        case .groupInvite:
            return "person.3.fill"
        case .repost:
            return "arrow.2.squarepath"
        }
    }

    /// Returns if this notification type should show an action button
    var hasActionButton: Bool {
        switch type {
        case .follow:
            return actorIsAnonymous == false
        case .loopInvite, .groupInvite:
            return true
        default:
            return false
        }
    }

    /// Returns the action button text
    var actionButtonText: String {
        switch type {
        case .follow:
            return "Follow Back"
        case .loopInvite:
            return "Join Loop"
        case .groupInvite:
            return "Join Group"
        default:
            return ""
        }
    }

    var previewText: String? {
        if let targetContent, !targetContent.isEmpty {
            return targetContent
        }
        if let body = trimmedBody, !body.isEmpty {
            return body
        }
        if isVerificationNotification {
            return resolvedVerificationBody
        }
        return nil
    }

    func updatingActor(name: String, profileImageUrl: String?) -> Notification {
        Notification(
            id: id,
            notificationUUID: notificationUUID,
            type: type,
            actorId: actorId,
            actorAnonProfileId: actorAnonProfileId,
            actorName: name,
            actorProfileImageUrl: profileImageUrl,
            actorIsAnonymous: actorIsAnonymous,
            additionalActors: additionalActors,
            targetId: targetId,
            targetCommentId: targetCommentId,
            targetContent: targetContent,
            title: title,
            body: body,
            category: category,
            verificationKind: verificationKind,
            verificationStatus: verificationStatus,
            verificationMethod: verificationMethod,
            verificationCommunityId: verificationCommunityId,
            verificationCommunityName: verificationCommunityName,
            verificationExpiresAt: verificationExpiresAt,
            verificationDaysRemaining: verificationDaysRemaining,
            verificationEventKey: verificationEventKey,
            verificationRejectReason: verificationRejectReason,
            announcementKind: announcementKind,
            announcementYears: announcementYears,
            deeplink: deeplink,
            actionDeeplink: actionDeeplink,
            fallbackDeeplink: fallbackDeeplink,
            privacyLevel: privacyLevel,
            reason: reason,
            newPostsCount: newPostsCount,
            since: since,
            communityId: communityId,
            mentionContext: mentionContext,
            isRead: isRead,
            createdAt: createdAt
        )
    }

    func markingRead() -> Notification {
        Notification(
            id: id,
            notificationUUID: notificationUUID,
            type: type,
            actorId: actorId,
            actorAnonProfileId: actorAnonProfileId,
            actorName: actorName,
            actorProfileImageUrl: actorProfileImageUrl,
            actorIsAnonymous: actorIsAnonymous,
            additionalActors: additionalActors,
            targetId: targetId,
            targetCommentId: targetCommentId,
            targetContent: targetContent,
            title: title,
            body: body,
            category: category,
            verificationKind: verificationKind,
            verificationStatus: verificationStatus,
            verificationMethod: verificationMethod,
            verificationCommunityId: verificationCommunityId,
            verificationCommunityName: verificationCommunityName,
            verificationExpiresAt: verificationExpiresAt,
            verificationDaysRemaining: verificationDaysRemaining,
            verificationEventKey: verificationEventKey,
            verificationRejectReason: verificationRejectReason,
            announcementKind: announcementKind,
            announcementYears: announcementYears,
            deeplink: deeplink,
            actionDeeplink: actionDeeplink,
            fallbackDeeplink: fallbackDeeplink,
            privacyLevel: privacyLevel,
            reason: reason,
            newPostsCount: newPostsCount,
            since: since,
            communityId: communityId,
            mentionContext: mentionContext,
            isRead: true,
            createdAt: createdAt
        )
    }

    private var trimmedTitle: String? {
        title?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBody: String? {
        body?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedVerificationKind: String? {
        verificationKind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var normalizedVerificationStatus: String? {
        verificationStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var verificationCommunityLabel: String? {
        let trimmed = verificationCommunityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var verificationRejectReasonLabel: String? {
        let trimmed = verificationRejectReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isVerificationNotification: Bool {
        guard type == .announcement else { return false }
        guard let kind = normalizedVerificationKind else { return false }
        guard kind == "community_verification" || kind == "user_verification" else { return false }
        guard let status = normalizedVerificationStatus else { return false }
        return Self.verificationStatuses.contains(status)
    }

    private var resolvedVerificationTitle: String {
        if let title = trimmedTitle, !title.isEmpty {
            return title
        }

        switch normalizedVerificationStatus {
        case "approved":
            if let community = verificationCommunityLabel {
                return "You're verified for \(community)"
            }
            return "You're verified"
        case "rejected":
            return "Verification rejected"
        case "expiring":
            if let days = verificationDaysRemaining, days > 0 {
                let dayLabel = days == 1 ? "day" : "days"
                return "Verification expires in \(days) \(dayLabel)"
            }
            return "Verification expiring soon"
        case "expired":
            return "Verification expired"
        default:
            return "Verification update"
        }
    }

    private var resolvedVerificationBody: String? {
        switch normalizedVerificationStatus {
        case "approved":
            if let community = verificationCommunityLabel {
                return "Your verification for \(community) is approved."
            }
            return "Your verification is approved."
        case "rejected":
            if let reason = verificationRejectReasonLabel {
                return "Your verification wasn't approved: \(reason)"
            }
            return "Your verification wasn't approved."
        case "expiring":
            if let community = verificationCommunityLabel, let days = verificationDaysRemaining, days > 0 {
                let dayLabel = days == 1 ? "day" : "days"
                return "Your verification for \(community) expires in \(days) \(dayLabel)."
            }
            if let days = verificationDaysRemaining, days > 0 {
                let dayLabel = days == 1 ? "day" : "days"
                return "Your verification expires in \(days) \(dayLabel)."
            }
            return "Your verification is expiring soon."
        case "expired":
            if let community = verificationCommunityLabel {
                return "Your verification for \(community) has expired. Re-verify to keep posting."
            }
            return "Your verification has expired. Re-verify to keep posting."
        default:
            return nil
        }
    }

    private static let verificationStatuses: Set<String> = [
        "approved",
        "rejected",
        "expiring",
        "expired"
    ]
}
