import SwiftUI
import Combine

enum SearchResultsFilter: String, CaseIterable, Identifiable {
    case users = "Users"
    case posts = "Posts"
    case all = "All"
    case communities = "Communities"
    case companies = "Companies"
    case fields = "Fields"

    var id: String { rawValue }

    static var uiCases: [SearchResultsFilter] {
        [.all, .posts, .users, .communities, .companies, .fields]
    }

    var searchKind: CommunitySearchKind? {
        switch self {
        case .companies:
            return .company
        case .fields:
            return .field
        default:
            return nil
        }
    }
}

@MainActor
class SearchResultsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedFilter: SearchResultsFilter?
    @Published var isSearching = false
    @Published var recentSearches: [String] = []
    @Published var searchResults: SearchResults = SearchResults()
    @Published var hashtagSuggestions: [String] = []
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let searchDebounceTime: TimeInterval = 0.3
    private let userService: UserServiceProtocol
    private let discoveryService: DiscoveryServiceProtocol
    private let communityService: CommunityServiceProtocol
    private let feedService: FeedServiceProtocol
    private let blockService: BlockServiceProtocol
    private let recentSearchesKey = "recentSearches"
    private let recentSearchesLimit = 5
    private var blockedUserIds: Set<Int> = []
    private var blockedPrincipalIds: Set<Int> = []
    private var blockedUsersLastSyncedAt: Date?

    init(
        userService: UserServiceProtocol = UserService(),
        discoveryService: DiscoveryServiceProtocol = DiscoveryService(),
        communityService: CommunityServiceProtocol = CommunityService(),
        feedService: FeedServiceProtocol = FeedService(),
        blockService: BlockServiceProtocol = BlockService()
    ) {
        self.userService = userService
        self.discoveryService = discoveryService
        self.communityService = communityService
        self.feedService = feedService
        self.blockService = blockService
        loadRecentSearches()
        setupSearchDebouncing()
        NotificationCenter.default.publisher(for: .userBlockListChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.refreshBlockedUsersIfNeeded(force: true)
                    self.searchResults = self.applyingBlockFilters(to: self.searchResults)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Search Debouncing
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .seconds(searchDebounceTime), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchQuery in
                guard let self else { return }
                Task { await self.performSearch(query: searchQuery, filter: self.selectedFilter) }
            }
            .store(in: &cancellables)

        $selectedFilter
            .removeDuplicates()
            .sink { [weak self] filter in
                guard let self else { return }
                Task { await self.performSearch(query: self.searchText, filter: filter) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Search Logic
    func performSearch(query: String, filter: SearchResultsFilter?) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            isSearching = false
            searchResults = SearchResults()
            hashtagSuggestions = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        await refreshBlockedUsersIfNeeded(force: false)
        do {
            var results = SearchResults()
            let isHashtagQuery = trimmedQuery.hasPrefix("#")
            switch filter {
            case .users:
                let page = try await userService.searchUsers(query: trimmedQuery, limit: 20, cursor: nil)
                results.people = page.users.map { user in
                    SearchResultPerson(
                        id: user.id,
                        backendId: user.backendId,
                        name: user.displayName ?? user.handle,
                        username: user.username ?? user.handle,
                        title: "Member",
                        company: user.company,
                        avatarURL: user.profileImageURL
                    )
                }
                searchResults = applyingBlockFilters(to: results)
                hashtagSuggestions = []
            case .posts:
                let page = try await feedService.searchPosts(query: trimmedQuery, limit: 20, cursor: nil)
                results.posts = page.posts.map { post in
                    SearchResultPost(post: post)
                }
                searchResults = applyingBlockFilters(to: results)
                hashtagSuggestions = []
            case .communities:
                let loopResults = try await communityService.searchCommunities(
                    query: trimmedQuery,
                    limit: 20,
                    cursor: nil,
                    kind: nil
                )
                results.loops = loopResults.items.map { loop in
                    SearchResultLoop(
                        id: UUID.fromBackendId(loop.id),
                        backendId: loop.id,
                        name: loop.name,
                        shortName: loop.shortName,
                        description: loop.description,
                        kind: loop.kind,
                        specializationType: loop.specializationType,
                        memberCount: loop.memberCount,
                        bannerImageUrl: loop.bannerImageUrl,
                        profileImageUrl: loop.profileImageUrl,
                        imageUrl: loop.imageUrl,
                        iconImageUrl: loop.iconImageUrl,
                        icon: loop.icon
                    )
                }
                searchResults = applyingBlockFilters(to: results)
                hashtagSuggestions = []
            case .companies, .fields:
                let loopResults = try await communityService.searchCommunities(
                    query: trimmedQuery,
                    limit: 20,
                    cursor: nil,
                    kind: filter?.searchKind
                )
                results.loops = loopResults.items.map { loop in
                    SearchResultLoop(
                        id: UUID.fromBackendId(loop.id),
                        backendId: loop.id,
                        name: loop.name,
                        shortName: loop.shortName,
                        description: loop.description,
                        kind: loop.kind,
                        specializationType: loop.specializationType,
                        memberCount: loop.memberCount,
                        bannerImageUrl: loop.bannerImageUrl,
                        profileImageUrl: loop.profileImageUrl,
                        imageUrl: loop.imageUrl,
                        iconImageUrl: loop.iconImageUrl,
                        icon: loop.icon
                    )
                }
                searchResults = applyingBlockFilters(to: results)
                hashtagSuggestions = []
            case .all, .none:
                let hashtagQuery = isHashtagQuery ? String(trimmedQuery.dropFirst()) : trimmedQuery

                if isHashtagQuery {
                    let hashtags = try await discoveryService.searchHashtags(query: hashtagQuery, limit: 5, cursor: nil)
                    results.hashtags = hashtags.items.map { tag in
                        SearchResultHashtag(
                            name: tag.name.hasPrefix("#") ? tag.name : "#\(tag.name)",
                            usageCount: tag.usageCount
                        )
                    }
                    hashtagSuggestions = results.hashtags.map { $0.name }
                    searchResults = applyingBlockFilters(to: results)
                    break
                }

                async let peopleTask = userService.searchUsers(query: trimmedQuery, limit: 20, cursor: nil)
                async let loopsTask = communityService.searchCommunities(
                    query: trimmedQuery,
                    limit: 20,
                    cursor: nil,
                    kind: nil
                )
                async let hashtagTask = discoveryService.searchHashtags(query: hashtagQuery, limit: 5, cursor: nil)
                async let postsTask = feedService.searchPosts(query: trimmedQuery, limit: 10, cursor: nil)

                var errors: [Error] = []

                do {
                    let page = try await peopleTask
                    results.people = page.users.map { user in
                        SearchResultPerson(
                            id: user.id,
                            backendId: user.backendId,
                            name: user.displayName ?? user.handle,
                            username: user.username ?? user.handle,
                            title: "Member",
                            company: user.company,
                            avatarURL: user.profileImageURL
                        )
                    }
                } catch {
                    errors.append(error)
                }

                do {
                    let loopResults = try await loopsTask
                    results.loops = loopResults.items.map { loop in
                        SearchResultLoop(
                            id: UUID.fromBackendId(loop.id),
                            backendId: loop.id,
                            name: loop.name,
                            shortName: loop.shortName,
                            description: loop.description,
                            kind: loop.kind,
                            specializationType: loop.specializationType,
                            memberCount: loop.memberCount,
                            bannerImageUrl: loop.bannerImageUrl,
                            profileImageUrl: loop.profileImageUrl,
                            imageUrl: loop.imageUrl,
                            iconImageUrl: loop.iconImageUrl,
                            icon: loop.icon
                        )
                    }
                } catch {
                    errors.append(error)
                }

                do {
                    let hashtags = try await hashtagTask
                    results.hashtags = hashtags.items.map { tag in
                        SearchResultHashtag(
                            name: tag.name.hasPrefix("#") ? tag.name : "#\(tag.name)",
                            usageCount: tag.usageCount
                        )
                    }
                } catch {
                    errors.append(error)
                }

                do {
                    let postPage = try await postsTask
                    results.posts = postPage.posts.map { post in
                        SearchResultPost(post: post)
                    }
                } catch {
                    // Don't block the overall preview on posts failures.
                }

                hashtagSuggestions = results.hashtags.map { $0.name }
                searchResults = applyingBlockFilters(to: results)

                if results.isEmpty, let firstError = errors.first {
                    errorMessage = firstError.localizedDescription
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            searchResults = SearchResults()
            hashtagSuggestions = []
        }
        isSearching = false
    }

    // MARK: - Recent Searches Management
    func addRecentSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        // Remove if already exists
        recentSearches.removeAll { $0 == trimmedQuery }

        // Add to beginning
        recentSearches.insert(trimmedQuery, at: 0)

        // Keep only latest 10
        if recentSearches.count > recentSearchesLimit {
            recentSearches = Array(recentSearches.prefix(recentSearchesLimit))
        }

        saveRecentSearches()
    }

    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        saveRecentSearches()
    }

    func clearRecentSearches() {
        recentSearches.removeAll()
        saveRecentSearches()
    }

    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: recentSearchesKey)
    }

    private func refreshBlockedUsersIfNeeded(force: Bool) async {
        let cacheDuration: TimeInterval = 30
        if !force,
           let lastSync = blockedUsersLastSyncedAt,
           Date().timeIntervalSince(lastSync) < cacheDuration {
            return
        }

        do {
            var blockedUsers: [BlockedUser] = []
            var cursor: String?
            var visitedCursors = Set<String>()

            while true {
                let page = try await blockService.fetchBlockedUsers(limit: 100, cursor: cursor)
                blockedUsers.append(contentsOf: page.users)

                guard let nextCursor = page.nextCursor, !nextCursor.isEmpty else {
                    break
                }
                guard visitedCursors.contains(nextCursor) == false else {
                    break
                }
                visitedCursors.insert(nextCursor)
                cursor = nextCursor
            }

            blockedUserIds = Set(blockedUsers.map(\.backendId))
            blockedPrincipalIds = Set(blockedUsers.map(\.principalId))
            blockedUsersLastSyncedAt = Date()
        } catch {
            // Keep stale block cache when fetch fails.
        }
    }

    private func applyingBlockFilters(to results: SearchResults) -> SearchResults {
        var filtered = results
        filtered.people = results.people.filter { person in
            guard let backendId = person.backendId else { return true }
            return blockedUserIds.contains(backendId) == false
        }
        filtered.posts = results.posts.filter { item in
            let post = item.post
            if let authorBackendId = post.authorBackendId, blockedUserIds.contains(authorBackendId) {
                return false
            }
            if let authorPrincipalId = post.authorPrincipalId, blockedPrincipalIds.contains(authorPrincipalId) {
                return false
            }
            return true
        }
        return filtered
    }
}

// MARK: - Data Models
struct SearchResults {
    var people: [SearchResultPerson] = []
    var posts: [SearchResultPost] = []
    var loops: [SearchResultLoop] = []
    var hashtags: [SearchResultHashtag] = []

    var isEmpty: Bool {
        people.isEmpty && posts.isEmpty && loops.isEmpty && hashtags.isEmpty
    }
}
