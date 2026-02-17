import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct SearchPostsFeedViewModelTests {

    @Test
    func loadInitial_success_setsPostsAndClearsLoading() async {
        let service = MockFeedService()
        let expectedPosts = [TestFixtures.post(backendId: 1), TestFixtures.post(backendId: 2)]
        service.searchPostsHandler = { query, _, cursor in
            #expect(query == "swift")
            #expect(cursor == nil)
            return TestFixtures.feedPage(posts: expectedPosts, nextCursor: "next")
        }

        let viewModel = SearchPostsFeedViewModel(query: "swift", feedService: service)

        await viewModel.loadInitial()

        #expect(viewModel.posts.compactMap(\.backendId) == [1, 2])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(service.searchPostsCalls.count == 1)
    }

    @Test
    func loadInitial_emptyResults_setsEmptyState() async {
        let service = MockFeedService()
        service.searchPostsHandler = { _, _, _ in
            TestFixtures.feedPage(posts: [], nextCursor: nil)
        }

        let viewModel = SearchPostsFeedViewModel(query: "swift", feedService: service)
        await viewModel.loadInitial()

        #expect(viewModel.posts.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadInitial_error_setsErrorAndStopsLoading() async {
        let service = MockFeedService()
        service.searchPostsHandler = { _, _, _ in
            throw TestError(message: "search failed")
        }

        let viewModel = SearchPostsFeedViewModel(query: "swift", feedService: service)
        await viewModel.loadInitial()

        #expect(viewModel.posts.isEmpty)
        #expect(viewModel.errorMessage == "search failed")
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadInitial_retryAfterError_recovers() async {
        let service = MockFeedService()
        var callCount = 0
        service.searchPostsHandler = { _, _, _ in
            defer { callCount += 1 }
            if callCount == 0 {
                throw TestError(message: "temporary")
            }
            return TestFixtures.feedPage(posts: [TestFixtures.post(backendId: 42)], nextCursor: nil)
        }

        let viewModel = SearchPostsFeedViewModel(query: "swift", feedService: service)
        await viewModel.loadInitial()
        #expect(viewModel.errorMessage == "temporary")

        await viewModel.loadInitial()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.posts.compactMap(\.backendId) == [42])
        #expect(service.searchPostsCalls.count == 2)
    }

    @Test
    func loadMoreIfNeeded_appendsWhenCursorExistsAndCurrentItemNearEnd() async {
        let firstPagePosts = (1...10).map { TestFixtures.post(backendId: $0) }
        let secondPagePosts = [TestFixtures.post(backendId: 11), TestFixtures.post(backendId: 12)]
        let service = MockFeedService()

        service.searchPostsHandler = { _, _, cursor in
            if cursor == nil {
                return TestFixtures.feedPage(posts: firstPagePosts, nextCursor: "cursor-2")
            }
            return TestFixtures.feedPage(posts: secondPagePosts, nextCursor: nil)
        }

        let viewModel = SearchPostsFeedViewModel(query: "swift", feedService: service)
        await viewModel.loadInitial()
        await viewModel.loadMoreIfNeeded(currentPost: firstPagePosts[9])

        #expect(viewModel.posts.count == 12)
        #expect(viewModel.posts.last.flatMap(\.backendId) == 12)
        #expect(service.searchPostsCalls.count == 2)
        #expect(viewModel.isLoadingMore == false)
    }

    @Test
    func loadMoreIfNeeded_noopWhenCurrentItemNotNearEnd() async {
        let posts = (1...10).map { TestFixtures.post(backendId: $0) }
        let service = MockFeedService()

        service.searchPostsHandler = { _, _, _ in
            TestFixtures.feedPage(posts: posts, nextCursor: "cursor-2")
        }

        let viewModel = SearchPostsFeedViewModel(query: "swift", feedService: service)
        await viewModel.loadInitial()
        await viewModel.loadMoreIfNeeded(currentPost: posts[0])

        #expect(viewModel.posts.count == 10)
        #expect(service.searchPostsCalls.count == 1)
    }

    @Test
    func loadInitial_withBlankQuery_clearsStateWithoutServiceCall() async {
        let service = MockFeedService()
        let viewModel = SearchPostsFeedViewModel(query: "   ", feedService: service)

        await viewModel.loadInitial()

        #expect(viewModel.posts.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(service.searchPostsCalls.isEmpty)
    }

    @Test
    func updateAndRemovePost_modifyCollectionByBackendId() async {
        let service = MockFeedService()
        service.searchPostsHandler = { _, _, _ in
            TestFixtures.feedPage(posts: [TestFixtures.post(backendId: 1), TestFixtures.post(backendId: 2)], nextCursor: nil)
        }

        let viewModel = SearchPostsFeedViewModel(query: "swift", feedService: service)
        await viewModel.loadInitial()

        let updated = TestFixtures.post(backendId: 2, content: "Updated")
        viewModel.updatePost(updated)
        #expect(viewModel.posts.last?.content == "Updated")

        viewModel.removePost(backendId: 1)
        #expect(viewModel.posts.count == 1)
        #expect(viewModel.posts.first.flatMap(\.backendId) == 2)
    }
}
