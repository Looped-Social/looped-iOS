import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct FollowStateStoreTests {

    @Test
    func setFollowing_persistsUserAndAnonIds() {
        let suite = "looped.tests.follow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = FollowStateStore(defaults: defaults)
        store.setFollowing(true, userId: 100)
        store.setFollowing(true, anonProfileId: 200)

        #expect(store.isFollowing(userId: 100))
        #expect(store.isFollowing(anonProfileId: 200))

        let reloaded = FollowStateStore(defaults: defaults)
        #expect(reloaded.isFollowing(userId: 100))
        #expect(reloaded.isFollowing(anonProfileId: 200))

        defaults.removePersistentDomain(forName: suite)
    }

    @Test
    func reset_clearsPersistedFollowState() {
        let suite = "looped.tests.follow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = FollowStateStore(defaults: defaults)
        store.setFollowing(true, userId: 1)
        store.setFollowing(true, anonProfileId: 2)

        store.reset()

        #expect(store.followingUserIds.isEmpty)
        #expect(store.followingAnonProfileIds.isEmpty)

        let reloaded = FollowStateStore(defaults: defaults)
        #expect(reloaded.followingUserIds.isEmpty)
        #expect(reloaded.followingAnonProfileIds.isEmpty)

        defaults.removePersistentDomain(forName: suite)
    }
}
