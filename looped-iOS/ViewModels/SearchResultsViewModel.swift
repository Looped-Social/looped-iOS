import SwiftUI
import Combine

@MainActor
class SearchResultsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var followedCommunities: [CommunitySummary] = []
    @Published var selectedCommunityId: Int?
    @Published var isLoadingCommunities = false
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
        selectedCommunityId = nil
        loadRecentSearches()
        setupSearchDebouncing()
        Task { await loadFollowedCommunities() }
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
            async let loopsPage = communityService.searchCommunities(query: query, limit: 20, cursor: nil)
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let hashtagQuery = trimmedQuery.hasPrefix("#") ? String(trimmedQuery.dropFirst()) : trimmedQuery
            async let hashtagPage = discoveryService.searchHashtags(query: hashtagQuery, limit: 5, cursor: nil)

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

            results.loops = loopResults.items.map { loop in
                SearchResultLoop(
                    id: UUID.fromBackendId(loop.id),
                    backendId: loop.id,
                    name: loop.name,
                    description: loop.description,
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
        } catch {
            errorMessage = error.localizedDescription
            searchResults = SearchResults()
            hashtagSuggestions = []
        }
        isSearching = false
    }

    // MARK: - Community Filter Management
    func selectCommunity(_ community: CommunitySummary) {
        selectedCommunityId = community.id
    }

    func selectAllCommunities() {
        selectedCommunityId = nil
    }

    func loadFollowedCommunities() async {
        guard !isLoadingCommunities else { return }
        isLoadingCommunities = true
        defer { isLoadingCommunities = false }
        do {
            let page = try await communityService.fetchFollowedCommunities(limit: 50, cursor: nil)
            followedCommunities = page.items
        } catch {
            followedCommunities = []
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
