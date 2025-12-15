import SwiftUI
import Combine

@MainActor
class SearchResultsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var filters: [SearchFilterOption] = []
    @Published var selectedFilter: SearchFilterOption
    @Published var isSearching = false
    @Published var recentSearches: [String] = []
    @Published var searchResults: SearchResults = SearchResults()
    @Published var hashtagSuggestions: [String] = []
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let searchDebounceTime: TimeInterval = 0.3
    private let userService: UserServiceProtocol
    private let discoveryService: DiscoveryServiceProtocol

    private let defaultFilters: [SearchFilterOption] = [
        SearchFilterOption(title: "All", apiKey: "all"),
        SearchFilterOption(title: "Company", apiKey: "company")
    ]

    init(userService: UserServiceProtocol = UserService(), discoveryService: DiscoveryServiceProtocol = DiscoveryService()) {
        self.userService = userService
        self.discoveryService = discoveryService
        filters = defaultFilters
        selectedFilter = defaultFilters.first ?? SearchFilterOption(title: "All", apiKey: "all")
        loadRecentSearches()
        setupSearchDebouncing()
    }

    // MARK: - Search Debouncing
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .seconds(searchDebounceTime), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchQuery in
                Task {
                    await self?.performSearch(query: searchQuery)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Search Logic
    func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isSearching = false
            searchResults = SearchResults()
            hashtagSuggestions = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        do {
            async let peoplePage = userService.searchUsers(query: query, limit: 20, cursor: nil)
            async let loopsPage = discoveryService.searchLoops(query: query, limit: 20, cursor: nil)
            async let hashtagPage = discoveryService.searchHashtags(query: query, limit: 5, cursor: nil)

            let (page, loopResults, hashtags) = try await (peoplePage, loopsPage, hashtagPage)
            var results = SearchResults()
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

            if selectedFilter.apiKey == "all" || selectedFilter.apiKey == "company" {
                results.loops = loopResults.items.map { loop in
                    SearchResultLoop(
                        id: UUID.fromBackendId(loop.id),
                        backendId: loop.id,
                        name: loop.name,
                        description: loop.description,
                        memberCount: loop.memberCount
                    )
                }
            }

            hashtagSuggestions = hashtags.items.map { "#\($0.name.trimmingCharacters(in: .whitespacesAndNewlines))" }
            searchResults = results
        } catch {
            errorMessage = error.localizedDescription
            searchResults = SearchResults()
            hashtagSuggestions = []
        }
        isSearching = false
    }

    // MARK: - Filter Management
    func selectFilter(_ filter: SearchFilterOption) {
        selectedFilter = filter
        Task {
            await performSearch(query: searchText)
        }
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
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
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
        recentSearches = []
    }

    private func saveRecentSearches() {
        // In real app, save to UserDefaults or Core Data
        // UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
    }
}

// MARK: - Data Models
struct SearchResults {
    var people: [SearchResultPerson] = []
    var posts: [SearchResultPost] = []
    var loops: [SearchResultLoop] = []

    var isEmpty: Bool {
        people.isEmpty && posts.isEmpty && loops.isEmpty
    }
}
