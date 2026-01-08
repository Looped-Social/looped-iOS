import SwiftUI
import Combine
import UIKit

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let notificationService: NotificationServiceProtocol
    private let userService: UserServiceProtocol
    private let cacheStore: NotificationCacheStore
    private var nextCursor: String?
    private var actorCache: [Int: ActorProfile] = [:]

    init(
        notificationService: NotificationServiceProtocol = NotificationService(),
        userService: UserServiceProtocol = UserService(),
        cacheStore: NotificationCacheStore = NotificationCacheStore()
    ) {
        self.notificationService = notificationService
        self.userService = userService
        self.cacheStore = cacheStore
        self.notifications = cacheStore.load()
    }

    // MARK: - Load Notifications
    func loadNotifications() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await notificationService.fetchNotifications(limit: 50, cursor: nil)
            notifications = mergeCachedAndFetched(cached: notifications, fetched: page.notifications)
            nextCursor = page.nextCursor
            errorMessage = nil
            cacheStore.save(notifications)
            await hydrateActorProfiles(for: notifications)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh Notifications
    func refreshNotifications() async {
        nextCursor = nil
        await loadNotifications()
    }

    func loadMoreNotifications() async {
        guard !isLoadingMore else { return }
        guard let nextCursor, !nextCursor.isEmpty else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await notificationService.fetchNotifications(limit: 50, cursor: nextCursor)
            self.nextCursor = page.nextCursor
            notifications = mergeCachedAndFetched(cached: notifications, fetched: page.notifications)
            cacheStore.save(notifications)
            await hydrateActorProfiles(for: notifications)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Handle Notification Tap
    func handleNotificationTap(_ notification: Notification) {
        // Mark notification as read
        markAsRead(notification)

        if openDeeplink(notification.deeplink) {
            return
        }

        // Fallback routing if deeplink missing.
        switch notification.type {
        case .like, .comment, .reply, .mention, .repost:
            navigateToPost(notification.targetId)
        case .follow:
            if let actorId = notification.actorId {
                navigateToUserProfile(actorId)
            }
        case .postFromFollowed:
            navigateToPost(notification.targetId)
        case .announcement, .system:
            _ = openDeeplink(notification.actionDeeplink)
        case .loopInvite, .groupInvite:
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
                cacheStore.save(notifications)
            }
        }
    }

    // MARK: - Mark All As Read
    func markAllAsRead() {
        notifications = notifications.map { $0.markingRead() }
        cacheStore.save(notifications)
    }

    // MARK: - Navigation Helpers (TODO: Implement actual navigation)
    private func navigateToPost(_ postId: UUID?) {
        // TODO: Implement navigation to post detail
    }

    private func navigateToUserProfile(_ userId: UUID) {
        // TODO: Implement navigation to user profile
    }

    private func navigateToGroup(_ groupId: UUID?) {
        // TODO: Implement navigation to group
    }

    // MARK: - Action Helpers (TODO: Implement actual actions)
    private func followUser(_ userId: UUID) {
        // TODO: Implement follow user API call
    }

    private func joinLoop(_ loopId: UUID?) {
        // TODO: Implement join loop API call
    }

    private func joinGroup(_ groupId: UUID?) {
        // TODO: Implement join group API call
    }

    private func openDeeplink(_ deeplink: String?) -> Bool {
        guard let deeplink, let url = URL(string: deeplink) else { return false }
        UIApplication.shared.open(url)
        return true
    }

    private func hydrateActorProfiles(for notifications: [Notification]) async {
        let idsToFetch = Set(
            notifications.compactMap { notification in
                guard !notification.actorIsAnonymous else { return nil }
                guard notification.actorProfileImageUrl == nil else { return nil }
                return notification.actorId?.backendInt
            }
        )
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
                notification.actorIsAnonymous == false,
                notification.actorProfileImageUrl == nil
            else { return notification }
            return notification.updatingActor(name: profile.name, profileImageUrl: profile.profileImageUrl)
        }
    }

    private func mergeCachedAndFetched(cached: [Notification], fetched: [Notification]) -> [Notification] {
        var mergedById: [UUID: Notification] = [:]
        for item in cached {
            mergedById[item.id] = item
        }
        for item in fetched {
            mergedById[item.id] = item
        }
        return mergedById.values
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.uuidString > rhs.id.uuidString
            }
    }
}

private struct ActorProfile {
    let name: String
    let profileImageUrl: String?
}
