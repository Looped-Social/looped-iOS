import Foundation

@MainActor
final class UnderReviewViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let feedService: FeedServiceProtocol
    private let pageSize = 20
    private var nextCursor: String?
    private var fallbackUserId: Int?

    var hasMore: Bool {
        nextCursor != nil
    }

    init(feedService: FeedServiceProtocol = FeedService()) {
        self.feedService = feedService
    }

    func loadInitial(fallbackUserId: Int?) async {
        self.fallbackUserId = fallbackUserId
        nextCursor = nil
        posts = []
        await load(reset: true)
    }

    func loadMoreIfNeeded(current post: Post) async {
        let prefetchThreshold = 6
        guard nextCursor != nil else { return }
        guard !posts.isEmpty else { return }
        guard posts.suffix(prefetchThreshold).contains(where: { $0.id == post.id }) else { return }
        await load(reset: false)
    }

    func loadMore() async {
        await load(reset: false)
    }

    func refresh() async {
        await loadInitial(fallbackUserId: fallbackUserId)
    }

    func updatePost(_ updated: Post) {
        guard let backendId = updated.backendId else { return }
        if let index = posts.firstIndex(where: { $0.backendId == backendId }) {
            posts[index] = updated
        }
    }

    func removePost(_ post: Post) {
        guard let backendId = post.backendId else { return }
        posts.removeAll { $0.backendId == backendId }
    }
}

private extension UnderReviewViewModel {
    func load(reset: Bool) async {
        if reset {
            guard !isLoading else { return }
            isLoading = true
        } else {
            guard !isLoadingMore, nextCursor != nil else { return }
            isLoadingMore = true
        }

        errorMessage = nil
        defer {
            if reset {
                isLoading = false
            } else {
                isLoadingMore = false
            }
        }

        do {
            let page: UserContentPage
            do {
                page = try await feedService.fetchMyContent(
                    limit: pageSize,
                    cursor: reset ? nil : nextCursor,
                    includePostPreview: true
                )
            } catch {
                guard isNotFound(error), let fallbackUserId else { throw error }
                page = try await feedService.fetchUserContent(
                    userId: fallbackUserId,
                    limit: pageSize,
                    cursor: reset ? nil : nextCursor,
                    includePostPreview: true
                )
            }

            let underReview = page.items.compactMap { item -> Post? in
                guard case .post(let post) = item.payload else { return nil }
                return post.isUnderReview ? post : nil
            }

            if reset {
                posts = underReview
            } else {
                posts.append(contentsOf: underReview)
            }
            nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isNotFound(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let code):
                return code == 404
            case .apiError(let code, _, _):
                return code == 404
            default:
                return false
            }
        }
        return false
    }
}
