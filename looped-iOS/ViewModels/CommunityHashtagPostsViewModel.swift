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
        guard normalizedCursor(nextCursor) != nil else { return }
        guard let lastPost = posts.last else { return }
        guard currentPost.id == lastPost.id else { return }
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
        let requestCursor = reset ? nil : normalizedCursor(nextCursor)
        if reset {
            guard !isLoading else { return }
            isLoading = true
        } else {
            guard !isLoadingMore, requestCursor != nil else { return }
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
                cursor: requestCursor
            )
            let responseCursor = normalizedCursor(page.nextCursor)
            if reset {
                posts = deduplicatedPosts(page.posts)
                nextCursor = responseCursor
            } else {
                let merged = deduplicatedPosts(posts + page.posts)
                let addedCount = merged.count - posts.count
                if addedCount > 0 {
                    posts = merged
                }
                let cursorDidAdvance = responseCursor != requestCursor
                if addedCount == 0 || !cursorDidAdvance || page.posts.isEmpty {
                    nextCursor = nil
                } else {
                    nextCursor = responseCursor
                }
            }
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

    private func deduplicatedPosts(_ input: [Post]) -> [Post] {
        var seen = Set<String>()
        var output: [Post] = []
        output.reserveCapacity(input.count)

        for post in input {
            let key: String
            if let backendId = post.backendId {
                key = "b:\(backendId)"
            } else {
                key = "u:\(post.id.uuidString)"
            }
            if seen.insert(key).inserted {
                output.append(post)
            }
        }

        return output
    }

    private func normalizedCursor(_ cursor: String?) -> String? {
        guard let trimmed = cursor?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
