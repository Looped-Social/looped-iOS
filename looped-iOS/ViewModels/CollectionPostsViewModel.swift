import Foundation
import Combine

@MainActor
final class CollectionPostsViewModel: ObservableObject {
    enum CollectionType {
        case liked
        case saved
        case reposted
        case myReposts
        case user(userId: Int)
        case userReposts(userId: Int)
        case anonReposts(profileId: Int)
        case anon(profileId: Int)
        case empty
    }
    
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    
    private let collection: CollectionType
    private let feedService: FeedServiceProtocol
    private var nextCursor: String?
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    init(collection: CollectionType, feedService: FeedServiceProtocol = FeedService()) {
        self.collection = collection
        self.feedService = feedService
        NotificationCenter.default.publisher(for: .contentPreferencesChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.loadInitial() }
            }
            .store(in: &cancellables)
    }
    
    func loadInitial() async {
        guard !isLoading else { return }
        let existingPosts = posts
        nextCursor = nil

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await fetchPage(cursor: nil)
            posts = applyOverrides(to: page.posts)
            nextCursor = page.nextCursor
        } catch {
            if isCancellation(error) {
                posts = existingPosts
                return
            }
            posts = existingPosts
            errorMessage = error.localizedDescription
        }
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
        defer {
            if reset {
                isLoading = false
            } else {
                isLoadingMore = false
            }
        }
        
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
            if isCancellation(error) { return }
            errorMessage = error.localizedDescription
        }
    }
    
    private func fetchPage(cursor: String?) async throws -> FeedPage {
        switch collection {
        case .liked:
            return try await feedService.fetchLikedPosts(limit: pageSize, cursor: cursor)
        case .saved:
            return try await feedService.fetchSavedPosts(limit: pageSize, cursor: cursor)
        case .reposted:
            return try await feedService.fetchRepostedPosts(limit: pageSize, cursor: cursor)
        case .myReposts:
            return try await feedService.fetchMyReposts(limit: pageSize, cursor: cursor)
        case .user(let userId):
            return try await feedService.fetchUserPosts(userId: userId, limit: pageSize, cursor: cursor)
        case .userReposts(let userId):
            return try await feedService.fetchUserReposts(userId: userId, limit: pageSize, cursor: cursor)
        case .anonReposts(let profileId):
            return try await feedService.fetchAnonReposts(anonProfileId: profileId, limit: pageSize, cursor: cursor)
        case .anon(let profileId):
            return try await feedService.fetchAnonPosts(anonProfileId: profileId, limit: pageSize, cursor: cursor)
        case .empty:
            return FeedPage(posts: [], nextCursor: nil)
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

    func updatePost(_ updated: Post) {
        guard let backendId = updated.backendId else { return }
        if let index = posts.firstIndex(where: { $0.backendId == backendId }) {
            let normalized = applyOverrides(to: [updated])
            posts[index] = normalized.first ?? updated
        }
    }
    
    private func applyOverrides(to posts: [Post]) -> [Post] {
        switch collection {
        case .liked:
            return posts.map { post in
                post.userReaction == .like ? post : post.updating(userReaction: .some(.like))
            }
        case .saved:
            return posts.map { $0.updating(isSaved: true) }
        default:
            return posts
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError(let underlying):
                return isCancellation(underlying)
            default:
                return false
            }
        }
        return false
    }
}
