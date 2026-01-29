import Foundation
import Combine

@MainActor
final class SearchPostsFeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let query: String
    private let feedService: FeedServiceProtocol
    private let pageSize = 20
    private var nextCursor: String?
    private var cancellables = Set<AnyCancellable>()

    init(query: String, feedService: FeedServiceProtocol = FeedService()) {
        self.query = query
        self.feedService = feedService
        NotificationCenter.default.publisher(for: .contentPreferencesChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.loadPosts(reset: true) }
            }
            .store(in: &cancellables)
    }

    func loadInitial() async {
        await loadPosts(reset: true)
    }

    func loadPosts(reset: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            posts = []
            nextCursor = nil
            isLoading = false
            isLoadingMore = false
            errorMessage = nil
            return
        }

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
            let page = try await feedService.searchPosts(
                query: trimmed,
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
        let prefetchThreshold = 6
        guard nextCursor != nil else { return }
        guard !posts.isEmpty else { return }
        guard posts.suffix(prefetchThreshold).contains(where: { $0.id == currentPost.id }) else { return }
        await loadPosts(reset: false)
    }

    func removePost(backendId: Int?) {
        guard let backendId else { return }
        posts.removeAll { $0.backendId == backendId }
    }

    func updatePost(_ updated: Post) {
        guard let backendId = updated.backendId else { return }
        if let index = posts.firstIndex(where: { $0.backendId == backendId }) {
            posts[index] = updated
        }
    }
}
