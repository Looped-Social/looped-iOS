import SwiftUI
import Combine

enum SearchResultsFilter: String, CaseIterable, Identifiable {
    case users = "Users"
    case all = "All"
    case communities = "Communities"
    case sectors = "Sectors"
    case companies = "Companies"
    case colleges = "Colleges"
    case majors = "Majors"
    case departments = "Departments"

    var id: String { rawValue }

    var searchKind: CommunitySearchKind? {
        switch self {
        case .sectors:
            return .sector
        case .companies:
            return .company
        case .colleges:
            return .school
        case .majors:
            return .major
        case .departments:
            return .department
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
    private let recentSearchesKey = "recentSearches"
    private let recentSearchesLimit = 5

    init(
        userService: UserServiceProtocol = UserService(),
        discoveryService: DiscoveryServiceProtocol = DiscoveryService(),
        communityService: CommunityServiceProtocol = CommunityService()
    ) {
        self.userService = userService
        self.discoveryService = discoveryService
        self.communityService = communityService
        loadRecentSearches()
        setupSearchDebouncing()
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
        do {
            var results = SearchResults()
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
                searchResults = results
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
                        description: loop.description,
                        kind: loop.kind,
                        specializationType: loop.specializationType,
                        memberCount: loop.memberCount,
                        imageUrl: loop.imageUrl
                    )
                }
                searchResults = results
                hashtagSuggestions = []
            case .sectors, .companies, .colleges, .majors, .departments:
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
                        description: loop.description,
                        kind: loop.kind,
                        specializationType: loop.specializationType,
                        memberCount: loop.memberCount,
                        imageUrl: loop.imageUrl
                    )
                }
                searchResults = results
                hashtagSuggestions = []
            case .all, .none:
                async let peoplePage = userService.searchUsers(query: trimmedQuery, limit: 20, cursor: nil)
                async let loopsPage = communityService.searchCommunities(
                    query: trimmedQuery,
                    limit: 20,
                    cursor: nil,
                    kind: nil
                )
                let hashtagQuery = trimmedQuery.hasPrefix("#") ? String(trimmedQuery.dropFirst()) : trimmedQuery
                async let hashtagPage = discoveryService.searchHashtags(query: hashtagQuery, limit: 5, cursor: nil)

                let (page, loopResults, hashtags) = try await (peoplePage, loopsPage, hashtagPage)
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

                results.loops = loopResults.items.map { loop in
                    SearchResultLoop(
                        id: UUID.fromBackendId(loop.id),
                        backendId: loop.id,
                        name: loop.name,
                        description: loop.description,
                        kind: loop.kind,
                        specializationType: loop.specializationType,
                        memberCount: loop.memberCount,
                        imageUrl: loop.imageUrl
                    )
                }

                results.hashtags = hashtags.items.map { tag in
                    SearchResultHashtag(
                        name: tag.name.hasPrefix("#") ? tag.name : "#\(tag.name)",
                        usageCount: tag.usageCount
                    )
                }
                hashtagSuggestions = results.hashtags.map { $0.name }
                searchResults = results
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
