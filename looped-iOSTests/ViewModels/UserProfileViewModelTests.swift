import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct UserProfileViewModelTests {

    @Test
    func loadProfile_syncsFollowingFromPaginatedBackendResults() async {
        let userService = MockUserService()
        userService.getUserHandler = { id in
            TestFixtures.user(backendId: id, followerCount: 4)
        }
        userService.fetchUserFollowingHandler = { _, _, cursor, _ in
            if cursor == nil {
                return UserFollowListPage(items: [TestFixtures.followListItem(entityId: 2, kind: .user)], nextCursor: "next")
            }
            return UserFollowListPage(items: [TestFixtures.followListItem(entityId: 42, kind: .user)], nextCursor: nil)
        }

        let followDefaults = makeDefaults(prefix: "profile.follow")
        let followStore = FollowStateStore(defaults: followDefaults)

        let viewModel = UserProfileViewModel(
            source: .user(id: 42),
            currentUserId: 7,
            userService: userService,
            followStateStore: followStore
        )

        await viewModel.loadProfile()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.profile?.backendId == 42)
        #expect(viewModel.isFollowing == true)
        #expect(followStore.isFollowing(userId: 42) == true)
        #expect(userService.fetchUserFollowingCalls.count == 2)
    }

    @Test
    func loadProfile_whenViewingSelf_forcesNotFollowing() async {
        let userService = MockUserService()
        userService.getUserHandler = { id in
            TestFixtures.user(backendId: id, followerCount: 1)
        }

        let followDefaults = makeDefaults(prefix: "profile.follow")
        let followStore = FollowStateStore(defaults: followDefaults)
        followStore.setFollowing(true, userId: 7)

        let viewModel = UserProfileViewModel(
            source: .user(id: 7),
            currentUserId: 7,
            userService: userService,
            followStateStore: followStore
        )

        await viewModel.loadProfile()

        #expect(viewModel.isFollowing == false)
        #expect(followStore.isFollowing(userId: 7) == false)
        #expect(userService.fetchUserFollowingCalls.isEmpty)
    }

    @Test
    func toggleFollow_success_updatesStateCountAndStore() async {
        let userService = MockUserService()
        userService.followUserHandler = { userId, _, _ in
            UserFollowActionResult(userId: userId, following: true)
        }

        let followDefaults = makeDefaults(prefix: "profile.follow")
        let followStore = FollowStateStore(defaults: followDefaults)
        let initial = UserProfile.from(user: TestFixtures.user(backendId: 42, followerCount: 10), isCurrentUser: false)

        let viewModel = UserProfileViewModel(
            source: .user(id: 42),
            currentUserId: 7,
            initialProfile: initial,
            userService: userService,
            followStateStore: followStore
        )

        await viewModel.toggleFollow(asAnonymousActor: false)

        #expect(viewModel.isFollowing == true)
        #expect(viewModel.profile?.followersCount == 11)
        #expect(viewModel.followErrorMessage == nil)
        #expect(followStore.isFollowing(userId: 42) == true)
        #expect(userService.followUserCalls.count == 1)
    }

    @Test
    func toggleFollow_failure_revertsAndShowsMappedError() async {
        let userService = MockUserService()
        userService.followUserHandler = { _, _, _ in
            throw APIError.apiError(code: 403, error: "forbidden", message: nil)
        }

        let followDefaults = makeDefaults(prefix: "profile.follow")
        let followStore = FollowStateStore(defaults: followDefaults)
        let initial = UserProfile.from(user: TestFixtures.user(backendId: 42, followerCount: 10), isCurrentUser: false)

        let viewModel = UserProfileViewModel(
            source: .user(id: 42),
            currentUserId: 7,
            initialProfile: initial,
            userService: userService,
            followStateStore: followStore
        )

        await viewModel.toggleFollow(asAnonymousActor: false)

        #expect(viewModel.isFollowing == false)
        #expect(viewModel.profile?.followersCount == 10)
        #expect(viewModel.followErrorMessage == "You can’t follow that profile.")
        #expect(followStore.isFollowing(userId: 42) == false)
    }

    @Test
    func toggleFollow_whenAlreadyFollowing_unfollowsAndDecrements() async {
        let userService = MockUserService()
        userService.unfollowUserHandler = { userId, _, _ in
            UserFollowActionResult(userId: userId, following: false)
        }

        let followDefaults = makeDefaults(prefix: "profile.follow")
        let followStore = FollowStateStore(defaults: followDefaults)
        followStore.setFollowing(true, userId: 42)
        let initial = UserProfile.from(user: TestFixtures.user(backendId: 42, followerCount: 10), isCurrentUser: false)

        let viewModel = UserProfileViewModel(
            source: .user(id: 42),
            currentUserId: 7,
            initialProfile: initial,
            userService: userService,
            followStateStore: followStore
        )

        await viewModel.toggleFollow(asAnonymousActor: false)

        #expect(viewModel.isFollowing == false)
        #expect(viewModel.profile?.followersCount == 9)
        #expect(followStore.isFollowing(userId: 42) == false)
        #expect(userService.unfollowUserCalls.count == 1)
    }
}

private func makeDefaults(prefix: String) -> UserDefaults {
    let suite = "looped.tests.\(prefix).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
