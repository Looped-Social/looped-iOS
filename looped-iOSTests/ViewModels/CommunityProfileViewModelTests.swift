import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct CommunityProfileViewModelTests {
    @Test
    func loadMoreIfNeeded_onlyTriggersWhenCurrentPostIsLastPost() async {
        let feedService = MockFeedService()
        let communityService = MockCommunityService()

        let firstPagePosts = (1...10).map { TestFixtures.post(backendId: $0) }
        let secondPagePosts = [TestFixtures.post(backendId: 11), TestFixtures.post(backendId: 12)]
        feedService.fetchFeedHandler = { _, cursor, communityId, _ in
            #expect(communityId == 11)
            if cursor == nil {
                return TestFixtures.feedPage(posts: firstPagePosts, nextCursor: "cursor-2")
            }
            #expect(cursor == "cursor-2")
            return TestFixtures.feedPage(posts: secondPagePosts, nextCursor: nil)
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1234,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: feedService,
            communityService: communityService
        )

        await viewModel.loadIfNeeded()
        #expect(viewModel.posts.count == 10)
        #expect(feedService.fetchFeedCalls.count == 1)

        if let firstPost = viewModel.posts.first {
            await viewModel.loadMoreIfNeeded(currentPost: firstPost)
        }
        #expect(feedService.fetchFeedCalls.count == 1)

        if let lastPost = viewModel.posts.last {
            await viewModel.loadMoreIfNeeded(currentPost: lastPost)
        }
        #expect(feedService.fetchFeedCalls.count == 2)
        #expect(viewModel.posts.count == 12)
    }

    @Test
    func loadMoreIfNeeded_staleCursorWithNoNewPosts_stopsFurtherPagination() async {
        let feedService = MockFeedService()
        let communityService = MockCommunityService()

        let firstPagePosts = [TestFixtures.post(backendId: 1), TestFixtures.post(backendId: 2), TestFixtures.post(backendId: 3)]
        let duplicatePagePosts = [TestFixtures.post(backendId: 3)]
        feedService.fetchFeedHandler = { _, cursor, communityId, _ in
            #expect(communityId == 11)
            if cursor == nil {
                return TestFixtures.feedPage(posts: firstPagePosts, nextCursor: "cursor-2")
            }
            #expect(cursor == "cursor-2")
            return TestFixtures.feedPage(posts: duplicatePagePosts, nextCursor: "cursor-2")
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1234,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: feedService,
            communityService: communityService
        )

        await viewModel.loadIfNeeded()
        #expect(viewModel.posts.compactMap(\.backendId) == [1, 2, 3])

        if let lastPost = viewModel.posts.last {
            await viewModel.loadMoreIfNeeded(currentPost: lastPost)
        }
        #expect(feedService.fetchFeedCalls.count == 2)
        #expect(viewModel.posts.compactMap(\.backendId) == [1, 2, 3])

        if let lastPost = viewModel.posts.last {
            await viewModel.loadMoreIfNeeded(currentPost: lastPost)
        }
        #expect(feedService.fetchFeedCalls.count == 2)
    }

    @Test
    func loadMoreIfNeeded_blankNextCursor_doesNotPaginate() async {
        let feedService = MockFeedService()
        let communityService = MockCommunityService()

        let firstPagePosts = [TestFixtures.post(backendId: 1), TestFixtures.post(backendId: 2)]
        feedService.fetchFeedHandler = { _, cursor, communityId, _ in
            #expect(communityId == 11)
            #expect(cursor == nil)
            return TestFixtures.feedPage(posts: firstPagePosts, nextCursor: "   ")
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1234,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: feedService,
            communityService: communityService
        )

        await viewModel.loadIfNeeded()
        #expect(feedService.fetchFeedCalls.count == 1)
        #expect(viewModel.posts.compactMap(\.backendId) == [1, 2])

        if let lastPost = viewModel.posts.last {
            await viewModel.loadMoreIfNeeded(currentPost: lastPost)
        }
        #expect(feedService.fetchFeedCalls.count == 1)
    }

    @Test
    func communityStateChanged_forSpecialization_refreshesJoinLimitEvenWhenDifferentCommunityChanges() async {
        let feedService = MockFeedService()
        let communityService = MockCommunityService()

        let initialLimit = makeJoinLimit(
            type: .major,
            canJoin: false,
            blockedReason: .verifySchool,
            requiredVerificationKind: .school,
            joinBlockedReason: .verificationRequired
        )
        let updatedLimit = makeJoinLimit(type: .major, canJoin: true)

        communityService.fetchSpecializationJoinLimitsHandler = { type in
            #expect(type == .major)
            return [updatedLimit]
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 300,
                name: "Computer Science",
                shortName: "CS",
                description: "",
                kind: .specialization,
                specializationType: .major,
                memberCount: 42,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: initialLimit
            ),
            feedService: feedService,
            communityService: communityService
        )

        NotificationCenter.default.post(
            name: .communityStateChanged,
            object: nil,
            userInfo: [LoopedNotificationUserInfoKey.communityId: 999]
        )
        await waitForNotificationTask()

        #expect(communityService.fetchSpecializationJoinLimitsCalls.isEmpty == false)
        #expect(communityService.fetchSpecializationJoinLimitsCalls.allSatisfy { $0 == .major })
        #expect(communityService.fetchCommunityDetailsDTOCalls.isEmpty)
        #expect(viewModel.community.joinLimit == updatedLimit)
    }

    @Test
    func communityStateChanged_forMatchingCompany_refreshesDetailsAndViewerState() async {
        let feedService = MockFeedService()
        let communityService = MockCommunityService()

        let refreshedDetails = CommunityDetailsDTO(
            id: 11,
            name: "UNC",
            shortName: "UNC",
            description: "Updated description",
            kind: "school",
            specializationType: nil,
            memberCount: 1234,
            bannerImageUrl: nil,
            profileImageUrl: nil,
            imageUrl: nil,
            icon: nil,
            isFollowing: true,
            isJoined: false,
            joinLimit: nil,
            viewer: CommunityViewerDTO(
                verificationStatus: .active,
                canPost: true,
                cannotPostReason: nil
            )
        )

        communityService.fetchCommunityDetailsDTOHandler = { communityId, kind in
            #expect(communityId == 11)
            #expect(kind == .school)
            return refreshedDetails
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "Old Name",
                shortName: nil,
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: feedService,
            communityService: communityService
        )

        NotificationCenter.default.post(
            name: .communityStateChanged,
            object: nil,
            userInfo: [LoopedNotificationUserInfoKey.communityId: 11]
        )
        await waitForNotificationTask()

        #expect(communityService.fetchCommunityDetailsDTOCalls.count == 1)
        #expect(communityService.fetchCommunityDetailsDTOCalls.first?.communityId == 11)
        #expect(communityService.fetchCommunityDetailsDTOCalls.first?.kind == .school)
        #expect(viewModel.community.name == "UNC")
        #expect(viewModel.viewerState?.verificationStatus == .active)
        #expect(viewModel.viewerState?.canPost == true)
    }

    @Test
    func connectRecommendedUser_whenAlreadyFollowing_unfollowsUserEvenWhenActionCannotConnect() async {
        let feedService = MockFeedService()
        let communityService = MockCommunityService()

        let recommendationService = MockPeopleRecommendationService()
        recommendationService.fetchRailsHandler = { surface, communityId, rails, limitPerRail in
            #expect(surface == .search)
            #expect(communityId == 11)
            #expect(rails == [.community])
            #expect(limitPerRail == 8)
            return PeopleRecommendationRailsBundle(
                requestId: "req-community-toggle",
                surface: .search,
                community: PeopleRecommendationCommunity(id: 11, name: "UNC"),
                rails: [
                    PeopleRecommendationRailPage(
                        requestId: "req-community-toggle",
                        rail: .community,
                        title: "People in UNC",
                        items: [makeCommunityRecommendationItem(userId: 9901, canConnect: false)],
                        nextCursor: nil,
                        hasMore: false,
                        degraded: false,
                        community: nil,
                        experiment: nil
                    )
                ],
                experiment: nil,
                degraded: false,
                generatedAt: Date()
            )
        }

        let userService = MockUserService()
        userService.unfollowUserHandler = { userId, _, _ in
            UserFollowActionResult(userId: userId, following: false)
        }

        let followStateStore = FollowStateStore(defaults: makeDefaults(prefix: "community.recommendation.toggle"))
        followStateStore.setFollowing(true, userId: 9901)

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1234,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: feedService,
            communityService: communityService,
            peopleRecommendationService: recommendationService,
            userService: userService,
            followStateStore: followStateStore
        )

        await viewModel.loadPeopleRecommendations(force: true)
        let item = #require(viewModel.peopleRecommendationsRail?.items.first)

        await viewModel.connectRecommendedUser(item)

        #expect(userService.followUserCalls.isEmpty)
        #expect(userService.unfollowUserCalls.count == 1)
        #expect(followStateStore.isFollowing(userId: 9901) == false)
        #expect(viewModel.isFollowingRecommendationUser(9901) == false)
    }

    @Test
    func shouldShowEmptyPostsNudge_requiresNotLoadingAndNoPosts() {
        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1234,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: MockFeedService(),
            communityService: MockCommunityService()
        )

        viewModel.posts = []
        viewModel.isLoading = false
        viewModel.hasLoadedInitialPosts = true
        #expect(viewModel.shouldShowEmptyPostsNudge)

        viewModel.isLoading = true
        #expect(!viewModel.shouldShowEmptyPostsNudge)

        viewModel.isLoading = false
        viewModel.posts = [TestFixtures.post(backendId: 1)]
        #expect(!viewModel.shouldShowEmptyPostsNudge)
    }

    @Test
    func emptyPostsNudgeMode_unverified_requiresVerificationOnceLoaded() async {
        let communityService = MockCommunityService()
        communityService.fetchCommunityDetailsDTOHandler = { _, _ in
            CommunityDetailsDTO(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: "school",
                specializationType: nil,
                memberCount: 1234,
                bannerImageUrl: nil,
                profileImageUrl: nil,
                imageUrl: nil,
                icon: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil,
                viewer: CommunityViewerDTO(
                    verificationStatus: .none,
                    canPost: false,
                    cannotPostReason: .notVerified
                )
            )
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1234,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: MockFeedService(),
            communityService: communityService
        )

        viewModel.posts = []
        viewModel.isLoading = false
        viewModel.hasLoadedInitialPosts = true
        #expect(viewModel.emptyPostsNudgeMode == .loadingVerification)

        await viewModel.loadCommunityDetails(force: true)
        #expect(viewModel.emptyPostsNudgeMode == .needsVerification)
    }

    @Test
    func emptyPostsNudgeMode_loadingVerification_whenNotYetLoaded() {
        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1234,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: MockFeedService(),
            communityService: MockCommunityService()
        )

        viewModel.posts = []
        viewModel.isLoading = false
        #expect(viewModel.emptyPostsNudgeMode == .loadingVerification)
    }

    @Test
    func emptyPostsNudgeMode_verified_afterViewerStateLoads() async {
        let communityService = MockCommunityService()
        communityService.fetchCommunityDetailsDTOHandler = { _, _ in
            CommunityDetailsDTO(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: "school",
                specializationType: nil,
                memberCount: 1234,
                bannerImageUrl: nil,
                profileImageUrl: nil,
                imageUrl: nil,
                icon: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil,
                viewer: CommunityViewerDTO(
                    verificationStatus: .active,
                    canPost: true,
                    cannotPostReason: nil
                )
            )
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "UNC",
                shortName: "UNC",
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1234,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: MockFeedService(),
            communityService: communityService
        )

        viewModel.posts = []
        viewModel.isLoading = false
        viewModel.hasLoadedInitialPosts = true
        #expect(viewModel.emptyPostsNudgeMode == .loadingVerification)

        await viewModel.loadCommunityDetails(force: true)
        #expect(viewModel.emptyPostsNudgeMode == .verified)
    }

    @Test
    func emptyPostsNudgeMode_needsJoin_whenViewerStateRequiresJoin() async {
        let communityService = MockCommunityService()
        communityService.fetchCommunityDetailsDTOHandler = { _, _ in
            CommunityDetailsDTO(
                id: 300,
                name: "Computer Science",
                shortName: "CS",
                description: "",
                kind: "specialization",
                specializationType: "major",
                memberCount: 42,
                bannerImageUrl: nil,
                profileImageUrl: nil,
                imageUrl: nil,
                icon: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil,
                viewer: CommunityViewerDTO(
                    verificationStatus: .active,
                    canPost: false,
                    cannotPostReason: .notJoined
                )
            )
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 300,
                name: "Computer Science",
                shortName: "CS",
                description: "",
                kind: .specialization,
                specializationType: .major,
                memberCount: 42,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: MockFeedService(),
            communityService: communityService
        )

        viewModel.posts = []
        viewModel.isLoading = false
        viewModel.hasLoadedInitialPosts = true
        #expect(viewModel.emptyPostsNudgeMode == .loadingVerification)

        await viewModel.loadCommunityDetails(force: true)
        #expect(viewModel.emptyPostsNudgeMode == .needsJoin)
    }
}

private func waitForNotificationTask() async {
    try? await Task.sleep(nanoseconds: 40_000_000)
}

private func makeJoinLimit(
    type: CommunitySpecializationType,
    canJoin: Bool,
    blockedReason: SpecializationJoinBlockedReason? = nil,
    requiredVerificationKind: SpecializationJoinRequiresVerificationKind? = nil,
    joinBlockedReason: SpecializationJoinBlockedReason? = nil
) -> SpecializationJoinLimit {
    let dto = SpecializationJoinLimitDTO(
        specializationType: type.rawValue,
        limit: 2,
        joinedCount: canJoin ? 1 : 2,
        remaining: canJoin ? 1 : 0,
        cooldownMonths: 6,
        cooldownActive: false,
        cooldownEndsAt: nil,
        cooldownDaysRemaining: nil,
        canJoin: canJoin,
        blockedReason: blockedReason?.rawValue,
        requiredVerificationKind: requiredVerificationKind?.rawValue,
        joinRequiresVerificationKind: requiredVerificationKind?.rawValue,
        joinBlockedReason: joinBlockedReason?.rawValue
    )
    return SpecializationJoinLimit(dto: dto)
}

private func makeVerification(
    communityId: Int,
    kind: CommunityKind,
    status: CommunityVerificationStatus
) -> CommunityVerification {
    CommunityVerification(
        communityId: communityId,
        communityName: "Community \(communityId)",
        communityKind: kind,
        method: .email,
        verified: status == .active || status == .expired,
        verifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
        expiresAt: nil,
        active: status == .active,
        status: status,
        rejectReason: nil,
        verifiedEmail: "user\(communityId)@example.com"
    )
}

private func makeCommunityRecommendationItem(userId: Int, canConnect: Bool) -> PeopleRecommendationItem {
    PeopleRecommendationItem(
        recommendationId: "community-rec-\(userId)",
        user: PeopleRecommendationUser(
            id: userId,
            handle: "user\(userId)",
            displayName: "User \(userId)",
            avatarURL: nil,
            headline: nil,
            community: nil
        ),
        reasons: [PeopleRecommendationReason(code: "community", text: "In your community")],
        actions: PeopleRecommendationActions(canConnect: canConnect, canHide: true, canLessLikeThis: true),
        tracking: PeopleRecommendationTracking(token: "trk-\(userId)", position: 1)
    )
}

private func makeDefaults(prefix: String) -> UserDefaults {
    let suite = "looped.tests.\(prefix).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
