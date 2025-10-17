import SwiftUI

struct SearchResultsView: View {
    @StateObject private var viewModel = SearchResultsViewModel()
    @StateObject private var commentsManager = CommentsModalManager()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFieldFocused: Bool
    @State private var selectedHashtag: String?
    @State private var showHashtagFeed = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Header
                searchHeader

                // Filter Tabs
                SearchFilterTabs(
                    filters: viewModel.filters,
                    selectedFilter: $viewModel.selectedFilter,
                    onFilterChange: viewModel.selectFilter
                )
                .padding(.vertical, 12)

                // Content Area
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Show recent searches when not searching
                        if viewModel.searchText.isEmpty {
                            recentSearchesSection
                        }
                        // Show search results when searching (includes hashtags + profiles)
                        else if !viewModel.searchResults.isEmpty || !viewModel.hashtagSuggestions.isEmpty {
                            searchResultsSection
                        }
                        // Show empty state when search has no results
                        else if !viewModel.isSearching && !viewModel.searchText.isEmpty {
                            emptySearchState
                        }
                        // Show loading state
                        else if viewModel.isSearching {
                            loadingState
                        }
                    }
                }
                .background(Color.loopedBackground)

                Spacer(minLength: 0)
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: Group {
                        if let hashtag = selectedHashtag {
                            HashtagFeedView(hashtag: hashtag)
                                .environmentObject(commentsManager)
                        }
                    },
                    isActive: $showHashtagFeed,
                    label: { EmptyView() }
                )
                .hidden()
            )
        }
        .navigationViewStyle(.stack)
        .onAppear {
            searchFieldFocused = true
        }
    }

    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 0) {
            SearchResultsBar(
                searchText: $viewModel.searchText,
                placeholder: "Search in \(MockSearchContent.companyFilterTitle)",
                onCancel: {
                    dismiss()
                },
                isSearchFieldFocused: $searchFieldFocused
            )
            .onSubmit {
                viewModel.addRecentSearch(viewModel.searchText)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Recent Searches Section
    private var recentSearchesSection: some View {
        VStack(spacing: 0) {
            if !viewModel.recentSearches.isEmpty {
                RecentSearchesSection(
                    recentSearches: viewModel.recentSearches,
                    onSearchTap: { query in
                        viewModel.searchText = query
                        viewModel.addRecentSearch(query)
                    },
                    onRemoveSearch: viewModel.removeRecentSearch
                )
            }
        }
    }

    // MARK: - Search Results Section
    private var searchResultsSection: some View {
        VStack(spacing: 0) {
            // Hashtag suggestions first (if any)
            if !viewModel.hashtagSuggestions.isEmpty {
                HashtagSuggestions(
                    hashtags: viewModel.hashtagSuggestions,
                    onHashtagTap: { hashtag in
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        // Remove # if present
                        let cleanHashtag = hashtag.hasPrefix("#") ? String(hashtag.dropFirst()) : hashtag
                        selectedHashtag = cleanHashtag
                        showHashtagFeed = true
                    }
                )

                // Divider between hashtags and profiles if we have both
                if !viewModel.searchResults.people.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }

            // Then profile/other results
            SearchResultsSection(
                results: viewModel.searchResults,
                onPostTap: { post in
                    // Navigate to post detail
                    print("Tapped post: \(post.content)")
                },
                onLoopTap: { loop in
                    // Navigate to loop
                    print("Tapped loop: \(loop.name)")
                }
            )
        }
    }

    // MARK: - Empty Search State
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No results found")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Text("Try a different search term")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.top, 60)
    }

    // MARK: - Loading State
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Searching...")
                .font(.loopedBody)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.top, 40)
    }
}

#Preview {
    SearchResultsView()
}
