import SwiftUI
import Combine

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Load Notifications
    func loadNotifications() async {
        isLoading = true
        defer { isLoading = false }

        // Simulate API delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Load mock data
        notifications = MockNotifications.getAllNotifications()
    }

    // MARK: - Refresh Notifications
    func refreshNotifications() async {
        // Simulate API refresh
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds

        // Reload mock data
        notifications = MockNotifications.getAllNotifications()
    }

    // MARK: - Handle Notification Tap
    func handleNotificationTap(_ notification: Notification) {
        // Mark notification as read
        markAsRead(notification)

        // Navigate to relevant content based on notification type
        switch notification.type {
        case .like, .comment, .reply, .mention, .repost:
            // Navigate to post/comment
            navigateToPost(notification.targetId)
        case .follow:
            // Navigate to user profile
            navigateToUserProfile(notification.actorId)
        case .loopInvite, .groupInvite:
            // Navigate to loop/group
            navigateToGroup(notification.targetId)
        }
    }

    // MARK: - Handle Action Button Tap
    func handleActionButtonTap(_ notification: Notification) {
        switch notification.type {
        case .follow:
            followUser(notification.actorId)
        case .loopInvite:
            joinLoop(notification.targetId)
        case .groupInvite:
            joinGroup(notification.targetId)
        default:
            break
        }
    }

    // MARK: - Mark As Read
    private func markAsRead(_ notification: Notification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = Notification(
                id: notifications[index].id,
                type: notifications[index].type,
                actorId: notifications[index].actorId,
                actorName: notifications[index].actorName,
                actorProfileImageUrl: notifications[index].actorProfileImageUrl,
                additionalActors: notifications[index].additionalActors,
                targetId: notifications[index].targetId,
                targetContent: notifications[index].targetContent,
                isRead: true,
                createdAt: notifications[index].createdAt
            )
        }
    }

    // MARK: - Mark All As Read
    func markAllAsRead() {
        notifications = notifications.map { notification in
            Notification(
                id: notification.id,
                type: notification.type,
                actorId: notification.actorId,
                actorName: notification.actorName,
                actorProfileImageUrl: notification.actorProfileImageUrl,
                additionalActors: notification.additionalActors,
                targetId: notification.targetId,
                targetContent: notification.targetContent,
                isRead: true,
                createdAt: notification.createdAt
            )
        }
    }

    // MARK: - Navigation Helpers (TODO: Implement actual navigation)
    private func navigateToPost(_ postId: UUID?) {
        print("Navigate to post: \(postId?.uuidString ?? "unknown")")
        // TODO: Implement navigation to post detail
    }

    private func navigateToUserProfile(_ userId: UUID) {
        print("Navigate to user profile: \(userId.uuidString)")
        // TODO: Implement navigation to user profile
    }

    private func navigateToGroup(_ groupId: UUID?) {
        print("Navigate to group: \(groupId?.uuidString ?? "unknown")")
        // TODO: Implement navigation to group
    }

    // MARK: - Action Helpers (TODO: Implement actual actions)
    private func followUser(_ userId: UUID) {
        print("Following user: \(userId.uuidString)")
        // TODO: Implement follow user API call
    }

    private func joinLoop(_ loopId: UUID?) {
        print("Joining loop: \(loopId?.uuidString ?? "unknown")")
        // TODO: Implement join loop API call
    }

    private func joinGroup(_ groupId: UUID?) {
        print("Joining group: \(groupId?.uuidString ?? "unknown")")
        // TODO: Implement join group API call
    }
}
