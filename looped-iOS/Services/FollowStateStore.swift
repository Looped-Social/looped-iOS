import Foundation
import Combine

@MainActor
final class FollowStateStore: ObservableObject {
    static let shared = FollowStateStore()

    @Published private(set) var followingUserIds: Set<Int>

    private let defaults: UserDefaults
    private let storageKey = "follow_state_store.following_user_ids"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.followingUserIds = Set(defaults.array(forKey: storageKey) as? [Int] ?? [])
    }

    func isFollowing(userId: Int) -> Bool {
        followingUserIds.contains(userId)
    }

    func setFollowing(_ following: Bool, userId: Int) {
        if following {
            followingUserIds.insert(userId)
        } else {
            followingUserIds.remove(userId)
        }
        persist()
    }

    func reset() {
        followingUserIds.removeAll()
        defaults.removeObject(forKey: storageKey)
    }

    private func persist() {
        defaults.set(Array(followingUserIds), forKey: storageKey)
    }
}

