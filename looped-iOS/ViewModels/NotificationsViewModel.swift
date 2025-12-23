import SwiftUI
import Combine
import UIKit

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let notificationService: NotificationServiceProtocol
    private let userService: UserServiceProtocol
    private var nextCursor: String?
    private var actorCache: [Int: ActorProfile] = [:]

    init(
        notificationService: NotificationServiceProtocol = NotificationService(),
        userService: UserServiceProtocol = UserService()
    ) {
        self.notificationService = notificationService
        self.userService = userService
    }

    // MARK: - Load Notifications
    func loadNotifications() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await notificationService.fetchNotifications(limit: 20, cursor: nil)
            notifications = page.notifications
            nextCursor = page.nextCursor
            errorMessage = nil
            await hydrateActorProfiles(for: page.notifications)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh Notifications
    func refreshNotifications() async {
        nextCursor = nil
        await loadNotifications()
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
            if let actorId = notification.actorId {
                navigateToUserProfile(actorId)
            }
        case .postFromFollowed:
            navigateToPost(notification.targetId)
        case .announcement, .system:
            if !openDeeplink(notification.deeplink) {
                print("No deeplink for notification: \(notification.id)")
            }
        case .loopInvite, .groupInvite:
            // Navigate to loop/group
            navigateToGroup(notification.targetId)
        }
    }

    // MARK: - Handle Action Button Tap
    func handleActionButtonTap(_ notification: Notification) {
        switch notification.type {
        case .follow:
            if let actorId = notification.actorId {
                followUser(actorId)
            }
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
        Task {
            if let backendId = notification.id.backendInt {
                try? await notificationService.markRead(notificationId: backendId)
            }
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index] = notifications[index].markingRead()
            }
        }
    }

    // MARK: - Mark All As Read
    func markAllAsRead() {
        notifications = notifications.map { $0.markingRead() }
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

    private func openDeeplink(_ deeplink: String?) -> Bool {
        guard let deeplink, let url = URL(string: deeplink) else { return false }
        UIApplication.shared.open(url)
        return true
    }

    private func hydrateActorProfiles(for notifications: [Notification]) async {
        let idsToFetch = Set(notifications.compactMap { $0.actorId?.backendInt })
            .subtracting(actorCache.keys)
        guard !idsToFetch.isEmpty else { return }

        var fetchedProfiles: [Int: ActorProfile] = [:]
        await withTaskGroup(of: (Int, ActorProfile)?.self) { group in
            for backendId in idsToFetch {
                group.addTask { [userService] in
                    do {
                        let user = try await userService.getUser(by: backendId)
                        let name = user.displayName ?? user.username ?? user.handle
                        return (backendId, ActorProfile(name: name, profileImageUrl: user.profileImageURL))
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let (id, profile) = result {
                    fetchedProfiles[id] = profile
                }
            }
        }

        if fetchedProfiles.isEmpty { return }
        actorCache.merge(fetchedProfiles) { _, new in new }
        self.notifications = self.notifications.map { notification in
            guard
                let backendId = notification.actorId?.backendInt,
                let profile = actorCache[backendId],
                notification.actorIsAnonymous == false
            else {
                return notification
            }
            return notification.updatingActor(name: profile.name, profileImageUrl: profile.profileImageUrl)
        }
    }
}

private struct ActorProfile {
    let name: String
    let profileImageUrl: String?
}
