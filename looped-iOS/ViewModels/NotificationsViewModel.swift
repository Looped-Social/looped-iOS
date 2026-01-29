import SwiftUI
import Combine
import UIKit

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var actionLoadingIds: Set<UUID> = []
    @Published private var followedActorIds: Set<Int> = []
    @Published var errorMessage: String?
    @Published var toastMessage: ToastMessage?

    private let notificationService: NotificationServiceProtocol
    private let userService: UserServiceProtocol
    private let cacheStore: NotificationCacheStore
    private let followStateStore: FollowStateStore
    private var nextCursor: String?
    private var actorCache: [Int: ActorProfile] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(
        notificationService: NotificationServiceProtocol = NotificationService(),
        userService: UserServiceProtocol = UserService(),
        cacheStore: NotificationCacheStore = NotificationCacheStore(),
        followStateStore: FollowStateStore = .shared
    ) {
        self.notificationService = notificationService
        self.userService = userService
        self.cacheStore = cacheStore
        self.followStateStore = followStateStore
        self.notifications = cacheStore.load()
        self.followedActorIds = followStateStore.followingUserIds

        followStateStore.$followingUserIds
            .receive(on: RunLoop.main)
            .sink { [weak self] ids in
                self?.followedActorIds = ids
            }
            .store(in: &cancellables)
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
            let shouldOpenComment = (notification.type == .comment || notification.type == .reply)
                && notification.targetCommentId != nil
            navigateToPost(
                notification.targetId,
                commentId: shouldOpenComment ? notification.targetCommentId : nil
            )
        case .follow:
            if notification.actorIsAnonymous, let actorAnonProfileId = notification.actorAnonProfileId {
                navigateToUserProfile(actorAnonProfileId, isAnonymous: true)
            } else if let actorId = notification.actorId {
                navigateToUserProfile(actorId, isAnonymous: false)
            }
        case .postFromFollowed:
            navigateToPost(notification.targetId)
        case .messageRequest:
            if openDeeplink(notification.actionDeeplink) { return }
            toastMessage = ToastMessage(text: "Message request isn't available yet.", kind: .info)
        case .announcement, .system:
            _ = openDeeplink(notification.actionDeeplink)
        case .loopInvite, .groupInvite:
            if openDeeplink(notification.actionDeeplink) { return }
            toastMessage = ToastMessage(text: "Invite destination isn't available yet.", kind: .info)
        }
    }

    // MARK: - Handle Action Button Tap
    func handleActionButtonTap(_ notification: Notification) {
        guard !actionLoadingIds.contains(notification.id) else { return }
        actionLoadingIds.insert(notification.id)

        Task {
            defer { actionLoadingIds.remove(notification.id) }

            switch notification.type {
            case .follow:
                if let actorId = notification.actorId {
                    await toggleFollow(actorId)
                } else {
                    toastMessage = ToastMessage(text: "Can't follow an anonymous profile yet.", kind: .error)
                }
            case .loopInvite, .groupInvite:
                if openDeeplink(notification.actionDeeplink) { return }
                toastMessage = ToastMessage(text: "Invite action isn't available yet.", kind: .info)
            default:
                break
            }
        }
    }

    func actionTitle(for notification: Notification) -> String? {
        switch notification.type {
        case .follow:
            guard let backendId = notification.actorId?.backendInt else { return nil }
            return followedActorIds.contains(backendId) ? "Following" : "Follow Back"
        case .loopInvite:
            return "Join Loop"
        case .groupInvite:
            return "Join Group"
        default:
            return nil
        }
    }

    func isActionEnabled(for notification: Notification) -> Bool {
        switch notification.type {
        case .follow:
            return notification.actorId?.backendInt != nil
        default:
            return true
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
    func markAllAsRead() async {
        let unreadNotifications = notifications.filter { !$0.isRead && $0.id.backendInt != nil }
        notifications = notifications.map { $0.markingRead() }
        cacheStore.save(notifications)

        do {
            for notification in unreadNotifications {
                guard let backendId = notification.id.backendInt else { continue }
                try await notificationService.markRead(notificationId: backendId)
            }
            toastMessage = ToastMessage(text: "Marked all as read", kind: .success)
        } catch {
            toastMessage = ToastMessage(text: "Couldn't mark all as read", kind: .error)
        }
    }

    // MARK: - Navigation Helpers
    private func navigateToPost(_ postId: UUID?, commentId: UUID? = nil) {
        guard let postId = postId?.backendInt else { return }
        if let commentId = commentId?.backendInt {
            _ = openInternalDeepLink(
                host: "comment",
                path: "/\(commentId)",
                queryItems: [URLQueryItem(name: "post_id", value: String(postId))]
            )
            return
        }
        _ = openInternalDeepLink(host: "post", path: "/\(postId)", queryItems: [])
    }

    private func navigateToUserProfile(_ userId: UUID, isAnonymous: Bool) {
        guard let backendId = userId.backendInt else { return }
        var queryItems: [URLQueryItem] = []
        if isAnonymous {
            queryItems.append(URLQueryItem(name: "anon", value: "true"))
        }
        _ = openInternalDeepLink(host: "user", path: "/\(backendId)", queryItems: queryItems)
    }

    private func navigateToGroup(_ groupId: UUID?) {
        toastMessage = ToastMessage(text: "Group invites aren't supported yet.", kind: .info)
    }

    // MARK: - Action Helpers
    private func toggleFollow(_ userId: UUID) async {
        guard let backendUserId = userId.backendInt else { return }
        if followedActorIds.contains(backendUserId) {
            do {
                let result = try await userService.unfollowUser(userId: backendUserId, asAnonymousActor: false, communityId: nil)
                if result.following == false {
                    followStateStore.setFollowing(false, userId: backendUserId)
                }
            } catch {
                toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
            }
            return
        }

        do {
            let result = try await userService.followUser(userId: backendUserId, asAnonymousActor: false, communityId: nil)
            if result.following {
                followStateStore.setFollowing(true, userId: backendUserId)
            }
        } catch {
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
        }
    }

    private func openDeeplink(_ deeplink: String?) -> Bool {
        guard let deeplink, let url = URL(string: deeplink) else { return false }
        UIApplication.shared.open(url)
        return true
    }

    private func openInternalDeepLink(host: String, path: String, queryItems: [URLQueryItem]) -> Bool {
        var components = URLComponents()
        components.scheme = "looped"
        components.host = host
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { return false }
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
