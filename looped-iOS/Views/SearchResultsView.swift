import SwiftUI

struct SearchResultsView: View {
    @StateObject private var viewModel = SearchResultsViewModel()
    @EnvironmentObject private var commentsManager: CommentsModalManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFieldFocused: Bool
    @State private var selectedHashtag: String?
    @State private var showHashtagFeed = false
    @State private var submittedQuery: String?
    @State private var showPostSearchFeed = false
    @State private var selectedCommunity: CommunityProfileData?
    @State private var showCommunityProfile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchTypeFilterPills(
                    selectedFilter: viewModel.selectedFilter,
                    onSelect: { viewModel.selectedFilter = $0 }
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
                        // Errors
                        else if let error = viewModel.errorMessage {
                            errorState(error)
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
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedPrimary)
                }
            }
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search Looped"
            )
            .searchFocused($searchFieldFocused)
            .onSubmit(of: .search) {
                handleSearchSubmit()
            }
            .background(
                Group {
                    NavigationLink(
                        destination: Group {
                            if let hashtag = selectedHashtag {
                                HashtagFeedView(hashtag: hashtag, presentationStyle: .navigation)
                                    .environmentObject(commentsManager)
                            }
                        },
                        isActive: $showHashtagFeed,
                        label: { EmptyView() }
                    )

                    NavigationLink(
                        destination: Group {
                            if let query = submittedQuery {
                                SearchPostsFeedView(query: query, presentationStyle: .navigation)
                                    .environmentObject(commentsManager)
                            }
                        },
                        isActive: $showPostSearchFeed,
                        label: { EmptyView() }
                    )

                    NavigationLink(
                        destination: Group {
                            if let community = selectedCommunity {
                                CommunityProfileView(community: community)
                            }
                        },
                        isActive: $showCommunityProfile,
                        label: { EmptyView() }
                    )
                }
                .hidden()
            )
        }
        .overlay(
            Group {
                if commentsManager.isPresented, let post = commentsManager.currentPost {
                    CommentsNavigationHost(post: post) {
                        commentsManager.dismissComments()
                    }
                    .environmentObject(commentsManager)
                    .transition(.move(edge: .trailing))
                }
            }
        )
        .onAppear {
            searchFieldFocused = true
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
                        handleHashtagTap(hashtag)
                    }
                )

                // Divider between hashtags and profiles if we have both
                if !viewModel.searchResults.people.isEmpty || !viewModel.searchResults.posts.isEmpty || !viewModel.searchResults.loops.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }

            // Then profile/other results
            SearchResultsSection(
                results: viewModel.searchResults,
                onPostTap: { searchPost in
                    searchFieldFocused = false
                    commentsManager.showComments(for: searchPost.post)
                },
                onLoopTap: { loop in
                    if let community = CommunityProfileData(loop: loop) {
                        selectedCommunity = community
                        showCommunityProfile = true
                    }
                },
                onHashtagTap: handleHashtagTap
            )
        }
    }

    // MARK: - Empty Search State
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.loopedCustom(size: 48))
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

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.loopedCustom(size: 40))
                .foregroundColor(.loopedTextSecondary.opacity(0.7))

            Text("Something went wrong")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Text(message)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 60)
    }

    private func handleHashtagTap(_ hashtag: String) {
        let trimmed = hashtag.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHashtag = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard !cleanHashtag.isEmpty else { return }
        selectedHashtag = cleanHashtag
        showHashtagFeed = true
    }

    private func handleSearchSubmit() {
        let trimmed = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchFieldFocused = false
        viewModel.addRecentSearch(trimmed)

        if trimmed.hasPrefix("#") {
            handleHashtagTap(trimmed)
            return
        }

        let filter = viewModel.selectedFilter
        if filter == nil || filter == .all || filter == .posts {
            submittedQuery = trimmed
            showPostSearchFeed = true
        }
    }
}

#Preview {
    SearchResultsView()
        .environmentObject(CommentsModalManager())
        .environmentObject(FeedViewModel())
        .environmentObject(AuthViewModel())
}
