import Foundation

@MainActor
final class HashtagFeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let feedService: FeedServiceProtocol
    private let pageSize = 20
    private var nextCursor: String?
    private let hashtag: String

    init(hashtag: String, feedService: FeedServiceProtocol = FeedService()) {
        self.hashtag = hashtag
        self.feedService = feedService
    }

    func loadInitial() async {
        await loadPosts(reset: true)
    }

    func loadPosts(reset: Bool) async {
        if reset {
            if isLoading { return }
            isLoading = true
        } else {
            if isLoadingMore || nextCursor == nil { return }
            isLoadingMore = true
        }
        errorMessage = nil
        if reset { nextCursor = nil }

        do {
            let page = try await feedService.fetchHashtagPosts(
                hashtag: hashtag,
                limit: pageSize,
                cursor: reset ? nil : nextCursor
            )
            if reset {
                posts = page.posts
            } else {
                posts.append(contentsOf: page.posts)
            }
            nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }

        if reset {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }

    func loadMoreIfNeeded(currentPost: Post) async {
        guard let lastPost = posts.last, currentPost.id == lastPost.id else { return }
        await loadPosts(reset: false)
    }
}
