import Foundation
import Combine

enum UserFollowListSubject: Hashable {
    case user(userId: Int)
    case anon(anonProfileId: Int)
}

enum UserFollowListKind: Hashable {
    case followers
    case following

    var title: String {
        switch self {
        case .followers:
            return "Followers"
        case .following:
            return "Following"
        }
    }
}

@MainActor
final class UserFollowListViewModel: ObservableObject {
    @Published var items: [UserFollowListItem] = []
    @Published var query = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let subject: UserFollowListSubject
    private let kind: UserFollowListKind
    private let userService: UserServiceProtocol
    private let anonService: AnonService
    private let limit: Int
    private let searchDebounceTime: TimeInterval = 0.3

    private var cancellables = Set<AnyCancellable>()
    private var nextCursor: String?
    private var generation = 0

    init(
        subject: UserFollowListSubject,
        kind: UserFollowListKind,
        userService: UserServiceProtocol = UserService(),
        anonService: AnonService = .shared,
        limit: Int = 20
    ) {
        self.subject = subject
        self.kind = kind
        self.userService = userService
        self.anonService = anonService
        self.limit = limit
        setupSearchDebouncing()
    }

    func loadInitialIfNeeded() async {
        guard items.isEmpty, !isLoading else { return }
        await loadInitial()
    }

    func loadInitial() async {
        generation += 1
        nextCursor = nil
        await loadPage(cursor: nil, mode: .replace, generation: generation)
    }

    func refresh() async {
        await loadInitial()
    }

    func loadMoreIfNeeded(current item: UserFollowListItem) async {
        guard let nextCursor, !isLoading, !isLoadingMore else { return }
        guard item.id == items.last?.id else { return }
        await loadPage(cursor: nextCursor, mode: .append, generation: generation)
    }

    private enum LoadMode {
        case replace
        case append
    }

    private func loadPage(cursor: String?, mode: LoadMode, generation: Int) async {
        if mode == .replace {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        defer {
            if mode == .replace {
                isLoading = false
            } else {
                isLoadingMore = false
            }
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedQuery = trimmedQuery.isEmpty ? nil : trimmedQuery

        do {
            let page: UserFollowListPage
            switch (subject, kind) {
            case (.user(let userId), .followers):
                page = try await userService.fetchUserFollowers(
                    userId: userId,
                    limit: limit,
                    cursor: cursor,
                    query: resolvedQuery
                )
            case (.user(let userId), .following):
                page = try await userService.fetchUserFollowing(
                    userId: userId,
                    limit: limit,
                    cursor: cursor,
                    query: resolvedQuery
                )
            case (.anon(let anonProfileId), .followers):
                page = try await anonService.fetchFollowers(
                    anonProfileId: anonProfileId,
                    limit: limit,
                    cursor: cursor,
                    query: resolvedQuery
                )
            case (.anon(let anonProfileId), .following):
                page = try await anonService.fetchFollowing(
                    anonProfileId: anonProfileId,
                    limit: limit,
                    cursor: cursor,
                    query: resolvedQuery
                )
            }

            guard generation == self.generation else { return }
            errorMessage = nil
            nextCursor = page.nextCursor
            switch mode {
            case .replace:
                items = page.items
            case .append:
                items.append(contentsOf: page.items)
            }
        } catch {
            guard generation == self.generation else { return }
            errorMessage = resolvedErrorMessage(from: error)
            if mode == .replace {
                items = []
                nextCursor = nil
            }
        }
    }

    private func setupSearchDebouncing() {
        $query
            .dropFirst()
            .debounce(for: .seconds(searchDebounceTime), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.loadInitial() }
            }
            .store(in: &cancellables)
    }

    private func resolvedErrorMessage(from error: Error) -> String {
        guard case let APIError.apiError(_, apiError, message) = error else {
            return error.localizedDescription
        }

        switch apiError {
        case "forbidden":
            return "This list is private."
        case "not_found":
            return "That account no longer exists."
        case "user_not_provisioned":
            return "Finish setting up your account to view this list."
        case "unauthorized":
            return "Please sign in to view this list."
        default:
            return message ?? apiError
        }
    }
}

