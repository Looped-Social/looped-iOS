import Foundation

// MARK: - Notification Model
struct Notification: Codable, Identifiable {
    let id: UUID
    let type: NotificationType
    let actorId: UUID
    let actorName: String
    let actorProfileImageUrl: String?
    let additionalActors: [NotificationActor]? // For grouped notifications
    let targetId: UUID? // Post/Comment/User ID that was affected
    let targetContent: String? // Preview of post/comment content
    let isRead: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        type: NotificationType,
        actorId: UUID,
        actorName: String,
        actorProfileImageUrl: String? = nil,
        additionalActors: [NotificationActor]? = nil,
        targetId: UUID? = nil,
        targetContent: String? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.actorId = actorId
        self.actorName = actorName
        self.actorProfileImageUrl = actorProfileImageUrl
        self.additionalActors = additionalActors
        self.targetId = targetId
        self.targetContent = targetContent
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
    case loopInvite     // Someone invited you to a loop
    case groupInvite    // Someone added you to a group
    case repost         // Someone reposted your post
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
            return "\(actorText) mentioned you in a post"
        case .follow:
            return "\(actorText) started following you"
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
        case .follow, .loopInvite, .groupInvite:
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
}
