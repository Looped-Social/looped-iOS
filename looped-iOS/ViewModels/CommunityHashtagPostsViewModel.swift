import Foundation
import Combine

@MainActor
final class CommunityHashtagPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let feedService: FeedServiceProtocol
    private let communityId: Int
    private let pageSize = 20
    private var nextCursor: String?
    private var hasLoadedInitial = false
    private var cancellables = Set<AnyCancellable>()

    init(communityId: Int, feedService: FeedServiceProtocol = FeedService()) {
        self.communityId = communityId
        self.feedService = feedService
        NotificationCenter.default.publisher(for: .contentPreferencesChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refresh() }
            }
            .store(in: &cancellables)
    }

    func loadIfNeeded() async {
        guard !hasLoadedInitial else { return }
        hasLoadedInitial = true
        await loadPosts(reset: true)
    }

    func refresh() async {
        hasLoadedInitial = true
        await loadPosts(reset: true)
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

    private func loadPosts(reset: Bool) async {
        if reset {
            guard !isLoading else { return }
            isLoading = true
        } else {
            guard !isLoadingMore, nextCursor != nil else { return }
            isLoadingMore = true
        }

        errorMessage = nil

        if reset {
            nextCursor = nil
        }

        do {
            let page = try await feedService.fetchCommunityHashtagPosts(
                communityId: communityId,
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
            if reset {
                posts = []
            }
        }

        if reset {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }
}
