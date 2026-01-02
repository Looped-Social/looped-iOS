import Foundation

@MainActor
final class UserCommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let userService: UserServiceProtocol
    private var nextCursor: String?
    private var userId: Int?
    private let pageSize = 20

    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }

    func setUser(id: Int?) {
        guard userId != id else { return }
        userId = id
        comments = []
        nextCursor = nil
        errorMessage = nil
    }

    func loadInitial() async {
        guard !isLoading else { return }
        nextCursor = nil
        comments = []
        await load(reset: true)
    }

    func loadMoreIfNeeded(current comment: Comment) async {
        guard let last = comments.last, last.id == comment.id else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        guard !isLoading, !isLoadingMore, let userId else { return }
        if reset {
            isLoading = true
        } else {
            guard nextCursor != nil else { return }
            isLoadingMore = true
        }
        errorMessage = nil

        do {
            let page = try await userService.fetchUserComments(userId: userId, limit: pageSize, cursor: reset ? nil : nextCursor)
            if reset {
                comments = page.comments
            } else {
                comments.append(contentsOf: page.comments)
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
}

@MainActor
final class UserRepliesViewModel: ObservableObject {
    @Published var replies: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let userService: UserServiceProtocol
    private var nextCursor: String?
    private var userId: Int?
    private let pageSize = 20

    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }

    func setUser(id: Int?) {
        guard userId != id else { return }
        userId = id
        replies = []
        nextCursor = nil
        errorMessage = nil
    }

    func loadInitial() async {
        guard !isLoading else { return }
        nextCursor = nil
        replies = []
        await load(reset: true)
    }

    func loadMoreIfNeeded(current reply: Comment) async {
        guard let last = replies.last, last.id == reply.id else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        guard !isLoading, !isLoadingMore, let userId else { return }
        if reset {
            isLoading = true
        } else {
            guard nextCursor != nil else { return }
            isLoadingMore = true
        }
        errorMessage = nil

        do {
            let page = try await userService.fetchUserReplies(userId: userId, limit: pageSize, cursor: reset ? nil : nextCursor)
            if reset {
                replies = page.comments
            } else {
                replies.append(contentsOf: page.comments)
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
}
