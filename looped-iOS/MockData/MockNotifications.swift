import Foundation

struct MockNotifications {

    // MARK: - Mock Notification Data
    static let notifications: [Notification] = [
        // Recent unread notifications (last few hours)
        Notification(
            type: .like,
            actorId: UUID(),
            actorName: "Sarah Chen",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&crop=face",
            additionalActors: [
                NotificationActor(name: "Mike Rodriguez"),
                NotificationActor(name: "Alex Kim")
            ],
            targetContent: "Just shipped a major feature! 🚀 The new search functionality is lightning fast. Shoutout to the entire engineering team for the late nights debugging.",
            isRead: false,
            createdAt: Date().addingTimeInterval(-1800) // 30 min ago
        ),

        Notification(
            type: .comment,
            actorId: UUID(),
            actorName: "David Park",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face",
            targetContent: "Anyone else feel like our office coffee machine is plotting against us? Third time this week it's been 'out of order'",
            isRead: false,
            createdAt: Date().addingTimeInterval(-3600) // 1 hour ago
        ),

        Notification(
            type: .follow,
            actorId: UUID(),
            actorName: "Emily Watson",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&crop=face",
            isRead: false,
            createdAt: Date().addingTimeInterval(-5400) // 1.5 hours ago
        ),

        Notification(
            type: .reply,
            actorId: UUID(),
            actorName: "Jennifer Liu",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&h=100&fit=crop&crop=face",
            targetContent: "Absolutely amazing work! 🔥 The user flow feels so intuitive now.",
            isRead: false,
            createdAt: Date().addingTimeInterval(-7200) // 2 hours ago
        ),

        // Today (read)
        Notification(
            type: .mention,
            actorId: UUID(),
            actorName: "Marcus Johnson",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&crop=face",
            targetContent: "Hot take: our current sprint planning process is broken. We consistently overcommit and then stress about hitting deadlines. Maybe it's time to try something different?",
            isRead: true,
            createdAt: Date().addingTimeInterval(-10800) // 3 hours ago
        ),

        Notification(
            type: .like,
            actorId: UUID(),
            actorName: "Priya Patel",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&h=100&fit=crop&crop=face",
            targetContent: "Design feedback: Love the clean aesthetic! The color palette works so well with the brand.",
            isRead: true,
            createdAt: Date().addingTimeInterval(-14400) // 4 hours ago
        ),

        Notification(
            type: .loopInvite,
            actorId: UUID(),
            actorName: "Ryan Cooper",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop&crop=face",
            isRead: true,
            createdAt: Date().addingTimeInterval(-21600) // 6 hours ago
        ),

        // Yesterday
        Notification(
            type: .comment,
            actorId: UUID(),
            actorName: "Lisa Anderson",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100&h=100&fit=crop&crop=face",
            additionalActors: [
                NotificationActor(name: "Tom Brady"),
                NotificationActor(name: "Nina Patel"),
                NotificationActor(name: "Chris Evans"),
                NotificationActor(name: "Amanda Green")
            ],
            targetContent: "This is absolutely incredible! The attention to detail in the micro-interactions really makes it shine.",
            isRead: true,
            createdAt: Date().addingTimeInterval(-86400) // 1 day ago
        ),

        Notification(
            type: .repost,
            actorId: UUID(),
            actorName: "James Wilson",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1519345182560-3f2917c472ef?w=100&h=100&fit=crop&crop=face",
            targetContent: "Remote work productivity tips that actually work",
            isRead: true,
            createdAt: Date().addingTimeInterval(-90000) // 25 hours ago
        ),

        Notification(
            type: .follow,
            actorId: UUID(),
            actorName: "Sophia Martinez",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100&h=100&fit=crop&crop=face",
            additionalActors: [
                NotificationActor(name: "Oliver Smith")
            ],
            isRead: true,
            createdAt: Date().addingTimeInterval(-95400) // 26.5 hours ago
        ),

        // 2 days ago
        Notification(
            type: .like,
            actorId: UUID(),
            actorName: "Daniel Kim",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop&crop=face",
            targetContent: "Fr tho, why is it always broken when you need it most? Murphy's law in action",
            isRead: true,
            createdAt: Date().addingTimeInterval(-172800) // 2 days ago
        ),

        Notification(
            type: .groupInvite,
            actorId: UUID(),
            actorName: "Rachel Green",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&h=100&fit=crop&crop=face",
            isRead: true,
            createdAt: Date().addingTimeInterval(-180000) // 2 days ago
        ),

        // 3 days ago
        Notification(
            type: .reply,
            actorId: UUID(),
            actorName: "Kevin Zhang",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100&h=100&fit=crop&crop=face",
            targetContent: "Thanks for sharing this! Really helpful insights 👍",
            isRead: true,
            createdAt: Date().addingTimeInterval(-259200) // 3 days ago
        ),

        Notification(
            type: .comment,
            actorId: UUID(),
            actorName: "Natalie Brooks",
            actorProfileImageUrl: "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100&h=100&fit=crop&crop=face",
            targetContent: "100% agree with this take. We've been saying this for months but nobody wanted to listen",
            isRead: true,
            createdAt: Date().addingTimeInterval(-270000) // 3+ days ago
        ),

        // 1 week ago
        Notification(
            type: .like,
            actorId: UUID(),
            actorName: "Anonymous",
            targetContent: "Proud to be part of this team! 🙌",
            isRead: true,
            createdAt: Date().addingTimeInterval(-604800) // 1 week ago
        )
    ]

    // MARK: - Helper Functions
    static func getUnreadCount() -> Int {
        return notifications.filter { !$0.isRead }.count
    }

    static func getUnreadNotifications() -> [Notification] {
        return notifications.filter { !$0.isRead }.sorted { $0.createdAt > $1.createdAt }
    }

    static func getAllNotifications() -> [Notification] {
        return notifications.sorted { $0.createdAt > $1.createdAt }
    }

    static func markAllAsRead() -> [Notification] {
        return notifications.map { notification in
            var updatedNotification = notification
            return Notification(
                id: updatedNotification.id,
                type: updatedNotification.type,
                actorId: updatedNotification.actorId,
                actorName: updatedNotification.actorName,
                actorProfileImageUrl: updatedNotification.actorProfileImageUrl,
                additionalActors: updatedNotification.additionalActors,
                targetId: updatedNotification.targetId,
                targetContent: updatedNotification.targetContent,
                isRead: true,
                createdAt: updatedNotification.createdAt
            )
        }
    }
}
