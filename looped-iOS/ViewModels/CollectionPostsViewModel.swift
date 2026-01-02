import Foundation

@MainActor
final class CollectionPostsViewModel: ObservableObject {
    enum CollectionType {
        case liked
        case saved
        case user(userId: Int)
    }
    
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    
    private let collection: CollectionType
    private let feedService: FeedServiceProtocol
    private var nextCursor: String?
    private let pageSize = 20
    
    init(collection: CollectionType, feedService: FeedServiceProtocol = FeedService()) {
        self.collection = collection
        self.feedService = feedService
    }
    
    func loadInitial() async {
        guard !isLoading else { return }
        nextCursor = nil
        posts = []
        await loadMore(reset: true)
    }
    
    func loadMoreIfNeeded(currentPost: Post) async {
        guard let last = posts.last, last.id == currentPost.id else { return }
        await loadMore(reset: false)
    }
    
    private func loadMore(reset: Bool) async {
        if reset {
            isLoading = true
        } else {
            guard !isLoadingMore, nextCursor != nil else { return }
            isLoadingMore = true
        }
        errorMessage = nil
        
        do {
            let page = try await fetchPage(cursor: reset ? nil : nextCursor)
            let normalized = applyOverrides(to: page.posts)
            if reset {
                posts = normalized
            } else {
                posts.append(contentsOf: normalized)
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
    
    private func fetchPage(cursor: String?) async throws -> FeedPage {
        switch collection {
        case .liked:
            return try await feedService.fetchLikedPosts(limit: pageSize, cursor: cursor)
        case .saved:
            return try await feedService.fetchSavedPosts(limit: pageSize, cursor: cursor)
        case .user(let userId):
            return try await feedService.fetchUserPosts(userId: userId, limit: pageSize, cursor: cursor)
        }
    }
    
    func handleBookmarkChange(for post: Post, isSaved: Bool) {
        guard case .saved = collection, !isSaved else { return }
        posts.removeAll { $0.id == post.id }
    }

    func removePost(backendId: Int?) {
        guard let backendId else { return }
        posts.removeAll { $0.backendId == backendId }
    }
    
    private func applyOverrides(to posts: [Post]) -> [Post] {
        switch collection {
        case .saved:
            return posts.map { $0.updating(isSaved: true) }
        default:
            return posts
        }
    }
}
