import Foundation

@MainActor
final class UserCommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var postLookup: [Int: Post] = [:]

    private enum Target: Equatable {
        case user(Int)
        case anon(Int)
    }

    private let userService: UserServiceProtocol
    private let apiClient: APIClient
    private let feedService: FeedServiceProtocol
    private var nextCursor: String?
    private var target: Target?
    private let pageSize = 20
    private var loadingPostIds = Set<Int>()
    private var unavailablePostIds = Set<Int>()

    init(
        userService: UserServiceProtocol = UserService(),
        apiClient: APIClient = APIClient(),
        feedService: FeedServiceProtocol = FeedService()
    ) {
        self.userService = userService
        self.apiClient = apiClient
        self.feedService = feedService
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
        await load(reset: true)
    }

    func loadMoreIfNeeded(current comment: Comment) async {
        guard let last = comments.last, last.id == comment.id else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        guard !isLoading, !isLoadingMore, let target else { return }
        if reset {
            isLoading = true
        } else {
            guard nextCursor != nil else { return }
            isLoadingMore = true
        }
        errorMessage = nil

        do {
            let page: UserCommentsPage
            switch target {
            case .user(let userId):
                page = try await userService.fetchUserComments(
                    userId: userId,
                    limit: pageSize,
                    cursor: reset ? nil : nextCursor
                )
            case .anon(let anonProfileId):
                page = try await fetchAnonReplies(
                    anonProfileId: anonProfileId,
                    cursor: reset ? nil : nextCursor
                )
            }
            if reset {
                comments = page.comments
            } else {
                comments.append(contentsOf: page.comments)
            }
            nextCursor = page.nextCursor
        } catch {
            if !isCancellation(error) {
                errorMessage = error.localizedDescription
            }
        }

        if reset {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }

    private func updateTarget(_ newTarget: Target?) {
        guard target != newTarget else { return }
        target = newTarget
        comments = []
        nextCursor = nil
        errorMessage = nil
        postLookup = [:]
        loadingPostIds = []
        unavailablePostIds = []
    }

    func loadPostPreview(for comment: Comment) async {
        guard let postId = comment.postBackendId else { return }
        if postLookup[postId] != nil || loadingPostIds.contains(postId) { return }
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

    func postPreview(for comment: Comment) -> Post? {
        guard let postId = comment.postBackendId else { return nil }
        return postLookup[postId]
    }

    func isPostUnavailable(postId: Int?) -> Bool {
        guard let postId else { return false }
        return unavailablePostIds.contains(postId)
    }

    func fetchPostForReply(_ comment: Comment) async -> Post? {
        guard let postId = comment.postBackendId else { return nil }
        if let existing = postLookup[postId] { return existing }
        await loadPostPreview(for: comment)
        return postLookup[postId]
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

    private func fetchAnonReplies(anonProfileId: Int, cursor: String?) async throws -> UserCommentsPage {
        var endpoint = "/v1/anon/\(anonProfileId)/replies?limit=\(pageSize)"
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: CommentListResponseDTO = try await apiClient.get(endpoint)
        let comments = response.items.map(Comment.init(dto:))
        return UserCommentsPage(comments: comments, nextCursor: response.nextCursor)
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

@MainActor
final class UserRepliesViewModel: ObservableObject {
    @Published var replies: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var postLookup: [Int: Post] = [:]

    private let userService: UserServiceProtocol
    private let apiClient: APIClient
    private let anonService: AnonService
    private let feedService: FeedServiceProtocol
    private let anonQueryAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+/=&?"))
    private var nextCursor: String?
    private var userId: Int?
    private let pageSize = 20
    private var loadingPostIds = Set<Int>()
    private var unavailablePostIds = Set<Int>()

    init(
        userService: UserServiceProtocol = UserService(),
        apiClient: APIClient = APIClient(),
        anonService: AnonService = .shared,
        feedService: FeedServiceProtocol = FeedService()
    ) {
        self.userService = userService
        self.apiClient = apiClient
        self.anonService = anonService
        self.feedService = feedService
    }

    func setUser(id: Int?) {
        guard userId != id else { return }
        userId = id
        replies = []
        nextCursor = nil
        errorMessage = nil
        postLookup = [:]
        loadingPostIds = []
        unavailablePostIds = []
    }

    func loadInitial() async {
        guard !isLoading else { return }
        nextCursor = nil
        await load(reset: true)
    }

    func loadMoreIfNeeded(current reply: Comment) async {
        guard let last = replies.last, last.id == reply.id else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        guard !isLoading, !isLoadingMore else { return }
        if !anonService.isAnonymousEnabled, userId == nil {
            return
        }
        if reset {
            isLoading = true
        } else {
            guard nextCursor != nil else { return }
            isLoadingMore = true
        }
        errorMessage = nil

        do {
            let page: UserRepliesPage
            if anonService.isAnonymousEnabled {
                page = try await fetchAnonReplies(cursor: reset ? nil : nextCursor)
            } else {
                guard let userId else { throw APIError.invalidResponse }
                page = try await userService.fetchUserReplies(userId: userId, limit: pageSize, cursor: reset ? nil : nextCursor)
            }
            if reset {
                replies = page.comments
            } else {
                replies.append(contentsOf: page.comments)
            }
            nextCursor = page.nextCursor
        } catch {
            if !isCancellation(error) {
                errorMessage = error.localizedDescription
            }
        }

        if reset {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }

    func loadPostPreview(for reply: Comment) async {
        guard let postId = reply.postBackendId else { return }
        if postLookup[postId] != nil || loadingPostIds.contains(postId) { return }
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

    func postPreview(for reply: Comment) -> Post? {
        guard let postId = reply.postBackendId else { return nil }
        return postLookup[postId]
    }

    func isPostUnavailable(postId: Int?) -> Bool {
        guard let postId else { return false }
        return unavailablePostIds.contains(postId)
    }

    func fetchPostForReply(_ reply: Comment) async -> Post? {
        guard let postId = reply.postBackendId else { return nil }
        if let existing = postLookup[postId] { return existing }
        await loadPostPreview(for: reply)
        return postLookup[postId]
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

    private func fetchAnonReplies(cursor: String?) async throws -> UserRepliesPage {
        let anonContext = try await anonService.profileActionContext(for: .replies)
        var endpoint = "/v1/anon/\(anonContext.profileId)/replies?limit=\(pageSize)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        endpoint = appendAnonQuery(to: endpoint, context: anonContext)
        let response: CommentListResponseDTO = try await apiClient.get(
            endpoint,
            requiresAuth: false,
            headers: ["X-Actor": "anon"]
        )
        let comments = response.items.map(Comment.init(dto:))
        return UserRepliesPage(comments: comments, nextCursor: response.nextCursor)
    }

    private func appendAnonQuery(to endpoint: String, context: AnonActionContext) -> String {
        let encodedCert = context.cert.addingPercentEncoding(withAllowedCharacters: anonQueryAllowed) ?? context.cert
        let encodedKid = context.certKid.addingPercentEncoding(withAllowedCharacters: anonQueryAllowed) ?? context.certKid
        let encodedSig = context.signature.addingPercentEncoding(withAllowedCharacters: anonQueryAllowed) ?? context.signature
        let params = [
            "asAnon=true",
            "anonProfileId=\(context.profileId)",
            "anonCert=\(encodedCert)",
            "anonCertKid=\(encodedKid)",
            "anonSig=\(encodedSig)"
        ]
        return endpoint + "&" + params.joined(separator: "&")
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
