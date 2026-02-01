import Foundation
import Combine

@MainActor
final class FollowStateStore: ObservableObject {
    static let shared = FollowStateStore()

    @Published private(set) var followingUserIds: Set<Int>
    @Published private(set) var followingAnonProfileIds: Set<Int>

    private let defaults: UserDefaults
    private let userStorageKey = "follow_state_store.following_user_ids"
    private let anonStorageKey = "follow_state_store.following_anon_profile_ids"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.followingUserIds = Set(defaults.array(forKey: userStorageKey) as? [Int] ?? [])
        self.followingAnonProfileIds = Set(defaults.array(forKey: anonStorageKey) as? [Int] ?? [])
    }

    func isFollowing(userId: Int) -> Bool {
        followingUserIds.contains(userId)
    }

    func isFollowing(anonProfileId: Int) -> Bool {
        followingAnonProfileIds.contains(anonProfileId)
    }

    func setFollowing(_ following: Bool, userId: Int) {
        if following {
            followingUserIds.insert(userId)
        } else {
            followingUserIds.remove(userId)
        }
        persist()
    }

    func setFollowing(_ following: Bool, anonProfileId: Int) {
        if following {
            followingAnonProfileIds.insert(anonProfileId)
        } else {
            followingAnonProfileIds.remove(anonProfileId)
        }
        persist()
    }

    func reset() {
        followingUserIds.removeAll()
        followingAnonProfileIds.removeAll()
        defaults.removeObject(forKey: userStorageKey)
        defaults.removeObject(forKey: anonStorageKey)
    }

    private func persist() {
        defaults.set(Array(followingUserIds), forKey: userStorageKey)
        defaults.set(Array(followingAnonProfileIds), forKey: anonStorageKey)
    }
}
