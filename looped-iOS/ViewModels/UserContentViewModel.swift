import Foundation

@MainActor
final class UserContentViewModel: ObservableObject {
    private enum Target: Equatable {
        case me(userId: Int?)
        case user(Int)
        case anon(Int)
    }

    @Published var items: [UserContentItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var postLookup: [Int: Post] = [:]

    private let feedService: FeedServiceProtocol
    private var nextCursor: String?
    private var target: Target?
    private let pageSize = 20
    private var loadingPostIds = Set<Int>()
    private var unavailablePostIds = Set<Int>()
    private let includePostPreview = true

    init(userId: Int? = nil, feedService: FeedServiceProtocol = FeedService()) {
        if let userId {
            self.target = .user(userId)
        } else {
            self.target = nil
        }
        self.feedService = feedService
    }

    func setCurrentUser(userId: Int? = nil) {
        updateTarget(.me(userId: userId))
    }

    func setUser(id: Int?) {
        updateTarget(id.map(Target.user))
    }

    func setAnonProfile(id: Int?) {
        updateTarget(id.map(Target.anon))
    }

    func loadInitial() async {
        guard !isLoading else { return }
        nextCursor = nil
        items = []
        postLookup = [:]
        loadingPostIds = []
        unavailablePostIds = []
        await load(reset: true)
    }

    func loadMoreIfNeeded(current item: UserContentItem) async {
        guard let last = items.last, last.id == item.id else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        guard let target else { return }
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
            switch target {
            case .me(let fallbackUserId):
                do {
                    page = try await feedService.fetchMyContent(
                        limit: pageSize,
                        cursor: reset ? nil : nextCursor,
                        includePostPreview: includePostPreview
                    )
                } catch {
                    guard isNotFound(error), let fallbackUserId else { throw error }
                    page = try await feedService.fetchUserContent(
                        userId: fallbackUserId,
                        limit: pageSize,
                        cursor: reset ? nil : nextCursor,
                        includePostPreview: includePostPreview
                    )
                }
            case .user(let userId):
                page = try await feedService.fetchUserContent(
                    userId: userId,
                    limit: pageSize,
                    cursor: reset ? nil : nextCursor,
                    includePostPreview: includePostPreview
                )
            case .anon(let anonProfileId):
                page = try await feedService.fetchAnonContent(
                    anonProfileId: anonProfileId,
                    limit: pageSize,
                    cursor: reset ? nil : nextCursor,
                    includePostPreview: includePostPreview
                )
            }
            if reset {
                items = page.items
            } else {
                items.append(contentsOf: page.items)
            }
            nextCursor = page.nextCursor

            for item in page.items {
                switch item.payload {
                case .post(let post):
                    if let backendId = post.backendId {
                        postLookup[backendId] = post
                    }
                case .reply(_, let postPreview):
                    if let postPreview, let backendId = postPreview.backendId {
                        postLookup[backendId] = postPreview
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePost(_ updated: Post) {
        guard let backendId = updated.backendId else { return }
        for index in items.indices {
            if case .post(let post) = items[index].payload, post.backendId == backendId {
                items[index] = UserContentItem(
                    id: items[index].id,
                    createdAt: items[index].createdAt,
                    payload: .post(updated)
                )
            }
        }
        postLookup[backendId] = updated
    }

    func removePost(backendId: Int?) {
        guard let backendId else { return }
        items.removeAll { item in
            if case .post(let post) = item.payload {
                return post.backendId == backendId
            }
            return false
        }
        postLookup.removeValue(forKey: backendId)
    }

    private func updateTarget(_ newTarget: Target?) {
        guard target != newTarget else { return }
        target = newTarget
        items = []
        nextCursor = nil
        errorMessage = nil
        postLookup = [:]
        loadingPostIds = []
        unavailablePostIds = []
    }

    func loadPostPreview(for reply: UserContentReply) async {
        let postId = reply.postId
        if postLookup[postId] != nil || loadingPostIds.contains(postId) || unavailablePostIds.contains(postId) {
            return
        }
        loadingPostIds.insert(postId)
        defer { loadingPostIds.remove(postId) }
        do {
            let post = try await feedService.fetchPost(postId: postId)
            postLookup[postId] = post
        } catch {
            if isNotFound(error) {
                unavailablePostIds.insert(postId)
            }
        }
    }

    func postPreview(for reply: UserContentReply) -> Post? {
        postLookup[reply.postId]
    }

    func isPostUnavailable(postId: Int) -> Bool {
        unavailablePostIds.contains(postId)
    }

    private func isNotFound(_ error: Error) -> Bool {
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
