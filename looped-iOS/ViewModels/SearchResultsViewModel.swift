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

    private var cancellables = Set<AnyCancellable>()
    private let searchDebounceTime: TimeInterval = 0.3

    init() {
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
            searchResults = SearchResults()
            return
        }

        isSearching = true

        // Simulate API delay
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Mock search results based on query and filter
        let results = generateMockResults(for: query, filter: selectedFilter)
        searchResults = results
        isSearching = false
    }

    private func generateMockResults(for query: String, filter: SearchFilterOption) -> SearchResults {
        var results = SearchResults()

        // Generate hashtag suggestions based on query
        generateHashtagSuggestions(for: query)

        // Mock people results using actual UserProfiles
        if filter.apiKey == "all" || filter.apiKey == "company" {
            let searchResults = MockUserProfiles.searchUserProfiles(query: query)
            results.people = searchResults.map { profile in
                SearchResultPerson(
                    id: profile.id,
                    name: profile.displayName ?? "Anonymous",
                    username: profile.username,
                    title: profile.jobTitle,
                    company: profile.company,
                    avatarURL: profile.profileImageURL
                )
            }

            // If no specific search results, show some default profiles
            if results.people.isEmpty && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let defaultProfiles = Array(MockUserProfiles.profiles.prefix(3))
                results.people = defaultProfiles.map { profile in
                    SearchResultPerson(
                        id: profile.id,
                        name: profile.displayName ?? "Anonymous",
                        username: profile.username,
                        title: profile.jobTitle,
                        company: profile.company,
                        avatarURL: profile.profileImageURL
                    )
                }
            }
        }

        // Mock posts results (placeholder for future API integration)
        results.posts = []

        // Mock loops results
        if filter.apiKey == "all" || filter.apiKey == "company" {
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

        return results
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
