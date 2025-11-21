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

    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
        let availableFilters = MockSearchContent.filterOptions
        filters = availableFilters
        selectedFilter = availableFilters.first ?? SearchFilterOption(title: "All Loops", apiKey: "all")
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
        generateHashtagSuggestions(for: query)
        do {
            let page = try await userService.searchUsers(query: query, limit: 20, cursor: nil)
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
                let loopMatches = MockSearchContent.loopCategories.filter { loop in
                    query.isEmpty ? true : loop.title.localizedCaseInsensitiveContains(query) || loop.description.localizedCaseInsensitiveContains(query)
                }

                results.loops = loopMatches.map { loop in
                    SearchResultLoop(
                        id: loop.id,
                        name: loop.title,
                        description: loop.description,
                        memberCount: loop.memberCount
                    )
                }
            }

            results.posts = []
            searchResults = results
        } catch {
            errorMessage = error.localizedDescription
            searchResults = SearchResults()
        }
        isSearching = false
    }

    private func generateHashtagSuggestions(for query: String) {
        // Mock hashtag suggestions that relate to the search query
        let allHashtags = MockSearchContent.popularHashtags

        // Filter hashtags based on query or show popular ones
        if query.isEmpty {
            hashtagSuggestions = []
        } else {
            hashtagSuggestions = allHashtags.filter { hashtag in
                hashtag.lowercased().contains(query.lowercased()) ||
                query.lowercased().contains(hashtag.dropFirst().lowercased())
            }

            // If no matching hashtags, show some popular ones
            if hashtagSuggestions.isEmpty {
                hashtagSuggestions = Array(allHashtags.prefix(3))
            } else {
                hashtagSuggestions = Array(hashtagSuggestions.prefix(5))
            }
        }
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
        // Mock recent searches for now
        recentSearches = MockSearchContent.defaultRecentSearches
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
