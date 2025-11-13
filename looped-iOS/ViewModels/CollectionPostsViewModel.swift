import Foundation

@MainActor
final class CollectionPostsViewModel: ObservableObject {
    enum CollectionType {
        case liked
        case saved
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
    
    private func fetchPage(cursor: String?) async throws -> FeedPage {
        switch collection {
        case .liked:
            return try await feedService.fetchLikedPosts(limit: pageSize, cursor: cursor)
        case .saved:
            return try await feedService.fetchSavedPosts(limit: pageSize, cursor: cursor)
        }
    }
}
