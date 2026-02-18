import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct FeedViewModelTests {

    @Test
    func makeFeedFilterCommunities_prioritizesUniqueRecents() {
        let followed = [
            makeCommunity(id: 1, name: "One"),
            makeCommunity(id: 2, name: "Two"),
            makeCommunity(id: 3, name: "Three")
        ]
        let recents = [
            makeCommunity(id: 2, name: "Two"),
            makeCommunity(id: 4, name: "Four"),
            makeCommunity(id: 2, name: "Two Duplicate"),
            makeCommunity(id: 5, name: "Five")
        ]

        let merged = FeedViewModel.makeFeedFilterCommunities(
            followedCommunities: followed,
            recentFeedCommunities: recents
        )

        #expect(merged.map(\.id) == [2, 4, 5, 1, 3])
    }

    @Test
    func loadPosts_success_deduplicatesAndClearsLoading() async {
        clearFeedDefaults()

        let service = MockFeedService()
        let now = Date()
        service.fetchFeedHandler = { _, cursor, _, _ in
            #expect(cursor == nil)
            return TestFixtures.feedPage(posts: [
                TestFixtures.post(backendId: 1, createdAt: now),
                TestFixtures.post(backendId: 1, createdAt: now),
                TestFixtures.post(backendId: 2, createdAt: now)
            ], nextCursor: nil)
        }

        let viewModel = makeViewModel(feedService: service)
        await viewModel.loadPosts(reset: true)

        #expect(viewModel.posts.compactMap(\.backendId) == [1, 2])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(service.fetchFeedCalls.count == 1)
    }

    @Test
    func loadPosts_error_setsErrorAndStopsLoading() async {
        clearFeedDefaults()

        let service = MockFeedService()
        service.fetchFeedHandler = { _, _, _, _ in
            throw TestError(message: "feed failed")
        }

        let viewModel = makeViewModel(feedService: service)
        await viewModel.loadPosts(reset: true)

        #expect(viewModel.errorMessage == "feed failed")
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadMoreIfNeeded_appendsNextPageNearListEnd() async {
        clearFeedDefaults()

        let service = MockFeedService()
        service.fetchFeedHandler = { _, cursor, _, _ in
            if cursor == nil {
                return TestFixtures.feedPage(posts: (1...8).map { TestFixtures.post(backendId: $0) }, nextCursor: "next")
            }
            return TestFixtures.feedPage(posts: [TestFixtures.post(backendId: 9), TestFixtures.post(backendId: 10)], nextCursor: nil)
        }

        let viewModel = makeViewModel(feedService: service)
        await viewModel.loadPosts(reset: true)
        #expect(!viewModel.posts.isEmpty)
        let trigger = viewModel.posts.last ?? TestFixtures.post(backendId: -1)
        await viewModel.loadMoreIfNeeded(currentPost: trigger)

        #expect(viewModel.posts.compactMap(\.backendId) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        #expect(viewModel.isLoadingMore == false)
        #expect(service.fetchFeedCalls.count == 2)
    }

    @Test
    func checkForNewPosts_notAtTop_setsToastCount() async {
        clearFeedDefaults()

        let service = MockFeedService()
        let now = Date()
        service.fetchFeedHandler = { _, _, _, _ in
            TestFixtures.feedPage(posts: [
                TestFixtures.post(backendId: 8, createdAt: now.addingTimeInterval(10)),
                TestFixtures.post(backendId: 7, createdAt: now.addingTimeInterval(9)),
                TestFixtures.post(backendId: 6, createdAt: now.addingTimeInterval(8)),
                TestFixtures.post(backendId: 5, createdAt: now)
            ], nextCursor: nil)
        }

        let viewModel = makeViewModel(feedService: service)
        viewModel.posts = [TestFixtures.post(backendId: 5, createdAt: now)]

        await viewModel.checkForNewPosts(minCount: 2, cooldown: 60, isAtTop: false)

        #expect(viewModel.newPostsToastCount == 3)
    }

    @Test
    func checkForNewPosts_atTop_refreshesImmediately() async {
        clearFeedDefaults()

        let service = MockFeedService()
        let now = Date()
        var call = 0
        service.fetchFeedHandler = { _, _, _, _ in
            defer { call += 1 }
            if call == 0 {
                return TestFixtures.feedPage(posts: [
                    TestFixtures.post(backendId: 8, createdAt: now.addingTimeInterval(10)),
                    TestFixtures.post(backendId: 5, createdAt: now)
                ], nextCursor: nil)
            }
            return TestFixtures.feedPage(posts: [
                TestFixtures.post(backendId: 8, createdAt: now.addingTimeInterval(10)),
                TestFixtures.post(backendId: 7, createdAt: now.addingTimeInterval(9))
            ], nextCursor: nil)
        }

        let viewModel = makeViewModel(feedService: service)
        viewModel.posts = [TestFixtures.post(backendId: 5, createdAt: now)]

        await viewModel.checkForNewPosts(minCount: 1, cooldown: 60, isAtTop: true)

        #expect(call == 2)
        #expect(viewModel.posts.first.flatMap(\.backendId) == 8)
        #expect(viewModel.newPostsToastCount == nil)
    }

    @Test
    func checkForNewPosts_respectsExistingToastAndCooldown() async {
        clearFeedDefaults()

        let service = MockFeedService()
        let now = Date()
        service.fetchFeedHandler = { _, _, _, _ in
            TestFixtures.feedPage(posts: [
                TestFixtures.post(backendId: 8, createdAt: now.addingTimeInterval(10)),
                TestFixtures.post(backendId: 7, createdAt: now.addingTimeInterval(9)),
                TestFixtures.post(backendId: 6, createdAt: now.addingTimeInterval(8)),
                TestFixtures.post(backendId: 5, createdAt: now)
            ], nextCursor: nil)
        }

        let viewModel = makeViewModel(feedService: service)
        viewModel.posts = [TestFixtures.post(backendId: 5, createdAt: now)]

        await viewModel.checkForNewPosts(minCount: 2, cooldown: 60, isAtTop: false)
        #expect(viewModel.newPostsToastCount == 3)

        await viewModel.checkForNewPosts(minCount: 2, cooldown: 60, isAtTop: false)
        #expect(viewModel.newPostsToastCount == 3)

        viewModel.dismissNewPostsToast()
        await viewModel.checkForNewPosts(minCount: 2, cooldown: 60, isAtTop: false)
        #expect(viewModel.newPostsToastCount == nil)
    }

    @Test
    func createPost_anonymousQueuedForReview_recoversFromAnonContentWhenAvailable() async {
        clearFeedDefaults()
        let anonStore = AnonIdentityStore()
        anonStore.clearAll()
        anonStore.saveIdentity(
            AnonIdentity(
                profileId: 9001,
                handle: "anon9001",
                memberships: [
                    1: AnonCommunityMembership(
                        cert: "cert",
                        certKid: "kid",
                        certExpiresAt: Date().addingTimeInterval(3600)
                    )
                ]
            )
        )
        defer { anonStore.clearAll() }

        let service = MockFeedService()
        service.createPostHandler = { _, isAnonymous, _, _, _, _ in
            #expect(isAnonymous == true)
            throw APIError.apiError(code: 403, error: "content_under_review", message: nil)
        }
        service.fetchAnonContentHandler = { anonProfileId, _, _, _ in
            #expect(anonProfileId == 9001)
            let recovered = Post(
                id: UUID.fromBackendId(42),
                backendId: 42,
                authorBackendId: nil,
                authorPrincipalId: 9001,
                anonProfileId: 9001,
                content: "Hello from anon",
                authorId: UUID.fromBackendId(9001),
                authorDisplayName: nil,
                authorHandle: "anonymous",
                company: "Looped",
                communityId: 1,
                communityName: "Looped",
                communityShortName: "LP",
                communityKind: .company,
                isAnonymous: true,
                isUnderReview: true,
                reactionCount: 0,
                commentsCount: 0,
                shareCount: 0,
                userReaction: nil,
                attachments: nil,
                isSaved: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            return UserContentPage(
                items: [UserContentItem(id: "post-42", createdAt: Date(), payload: .post(recovered))],
                nextCursor: nil
            )
        }

        let viewModel = makeViewModel(feedService: service)
        let result = await viewModel.createPost(
            content: "  Hello from anon  ",
            isAnonymous: true,
            communityId: 1
        )

        #expect(result == .createdUnderReview)
        #expect(viewModel.posts.first?.backendId == 42)
        #expect(service.fetchAnonContentCalls.count == 1)
    }

    @Test
    func createPost_anonymousQueuedForReview_keepsQueuedWhenAnonContentMissing() async {
        clearFeedDefaults()
        let anonStore = AnonIdentityStore()
        anonStore.clearAll()
        anonStore.saveIdentity(
            AnonIdentity(
                profileId: 9002,
                handle: "anon9002",
                memberships: [
                    1: AnonCommunityMembership(
                        cert: "cert",
                        certKid: "kid",
                        certExpiresAt: Date().addingTimeInterval(3600)
                    )
                ]
            )
        )
        defer { anonStore.clearAll() }

        let service = MockFeedService()
        service.createPostHandler = { _, _, _, _, _, _ in
            throw APIError.apiError(code: 403, error: "content_under_review", message: nil)
        }
        service.fetchAnonContentHandler = { _, _, _, _ in
            UserContentPage(items: [], nextCursor: nil)
        }

        let viewModel = makeViewModel(feedService: service)
        let result = await viewModel.createPost(
            content: "Anon pending",
            isAnonymous: true,
            communityId: 1
        )

        #expect(result == .queuedForReview)
        #expect(viewModel.posts.isEmpty)
        #expect(service.fetchAnonContentCalls.count == 1)
    }
}

@MainActor
private func makeViewModel(feedService: MockFeedService) -> FeedViewModel {
    FeedViewModel(
        feedService: feedService,
        communityService: MockCommunityService(),
        mediaService: MockMediaService()
    )
}

private func makeCommunity(id: Int, name: String) -> CommunitySummary {
    CommunitySummary(
        id: id,
        name: name,
        shortName: nil,
        kind: .company,
        memberCount: id * 10,
        isPinned: false,
        sortOrder: nil,
        canPost: true
    )
}

private func clearFeedDefaults() {
    let keys = [
        "lastPostedCommunityId",
        "lastSelectedCommunityId",
        "feedActiveCommunityId",
        "feedRecentCommunities",
        "feedRecentCommunityId",
        "feedRecentCommunityName",
        "feedRecentCommunityShortName",
        "feedRecentCommunityKind",
        "feedRecentCommunityMemberCount"
    ]
    for key in keys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
