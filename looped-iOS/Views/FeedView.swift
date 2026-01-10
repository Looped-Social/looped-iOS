import SwiftUI

struct FeedView: View {
    let onProfileTap: () -> Void
    @Binding private var isTabBarVisible: Bool
    @EnvironmentObject var viewModel: FeedViewModel
    @State private var headerVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isAtTop = true
    @State private var pollingTask: Task<Void, Never>?

    private var headerHeight: CGFloat { viewModel.isCommunitySearchActive ? 380 : 140 }
    private let pollInterval: TimeInterval = 90
    private let toastCooldown: TimeInterval = 7 * 60
    private let minNewPostsCount = 7
    private let topAnchorId = "feedTop"

    init(
        isTabBarVisible: Binding<Bool> = .constant(true),
        onProfileTap: @escaping () -> Void = {}
    ) {
        self._isTabBarVisible = isTabBarVisible
        self.onProfileTap = onProfileTap
    }

    var body: some View {
        ZStack(alignment: .top) {

            // Simple native ScrollView with ScrollViewReader
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        Color.loopedClear
                            .frame(height: 0)
                            .id(topAnchorId)

                        if viewModel.isLoading && viewModel.posts.isEmpty {
                            ForEach(0..<6, id: \.self) { index in
                                PostCardSkeleton(showsMedia: index % 3 != 0)

                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
                            }
                        } else if viewModel.posts.isEmpty {
                            EmptyFeedView()
                        } else {
                            ForEach(viewModel.posts) { post in
                                PostCard(
                                    post: post,
                                    showsCommunityLabel: true,
                                    onUpdate: { updated in
                                        viewModel.updatePost(updated)
                                    },
                                    onDelete: { deleted in
                                        viewModel.removePost(backendId: deleted.backendId)
                                    }
                                )
                                    .onAppear {
                                        Task {
                                            await viewModel.loadMoreIfNeeded(currentPost: post)
                                        }
                                    }

                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                    .background(
                        GeometryReader { geo in
                            Color.loopedClear
                                .onChange(of: geo.frame(in: .global).minY) { _, newValue in
                                    handleScroll(newValue)
                                }
                        }
                    )
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.loopedClear.frame(height: headerHeight)
                }
                .refreshable {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        headerVisible = true
                        isTabBarVisible = true
                    }
                    await viewModel.loadInitial()
                }
                .overlay(alignment: .top) {
                    if let count = viewModel.newPostsToastCount {
                        FeedNewPostsToast(
                            count: count,
                            onTap: {
                                handleToastTap(proxy: proxy)
                            },
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.dismissNewPostsToast()
                                }
                            }
                        )
                        .padding(.top, headerVisible ? headerHeight + 12 : 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.newPostsToastCount)
            }

            // Fixed header with proper safe area handling
            VStack(spacing: 0) {
                FeedHeader(onProfileTap: onProfileTap)
                FeedTabs(
                    isSearching: $viewModel.isCommunitySearchActive,
                    searchQuery: $viewModel.communitySearchQuery,
                    communities: viewModel.feedFilterCommunities,
                    selectedCommunityId: viewModel.selectedCommunity?.id,
                    onSelectCommunity: { community in
                        Task { await viewModel.selectCommunity(community) }
                    },
                    onSelectAll: {
                        Task { await viewModel.selectAllCommunities() }
                    },
                    onLoadMore: { community in
                        Task { await viewModel.loadMoreFollowedCommunitiesIfNeeded(currentCommunity: community) }
                    },
                    onSelectMode: { mode in
                        Task { await viewModel.selectFeedMode(mode) }
                    },
                    searchResults: viewModel.communitySearchResults,
                    isSearchLoading: viewModel.isCommunitySearchLoading,
                    searchErrorMessage: viewModel.communitySearchError,
                    onSearchQueryChange: { query in
                        viewModel.updateCommunitySearchQuery(query)
                    },
                    onSelectSearchResult: { result in
                        Task { await viewModel.selectCommunityFromSearchResult(result) }
                    },
                    onDismissSearch: {
                        viewModel.dismissCommunitySearch()
                    }
                )
            }
            .frame(height: headerHeight)
            .background(
                Color.loopedBackground
                    .ignoresSafeArea(.all, edges: .top)
            )
            .offset(y: headerVisible ? 0 : -headerHeight)
            .opacity(headerVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: headerVisible)
        }
        .background(Color.loopedBackground)
        .navigationBarHidden(true)
        .task {
            await viewModel.loadInitial()
        }
        .onAppear {
            headerVisible = true
            isTabBarVisible = true
            lastScrollOffset = 0
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }


    private func handleScroll(_ offset: CGFloat) {
        if viewModel.isCommunitySearchActive {
            if !headerVisible || !isTabBarVisible {
                withAnimation(.easeInOut(duration: 0.2)) {
                    headerVisible = true
                    isTabBarVisible = true
                }
            }
            lastScrollOffset = offset
            return
        }

        let delta = offset - lastScrollOffset
        var updatedVisibility: Bool?

        // Show header when near top
        if offset >= -50 {
            updatedVisibility = true
        }
        // Hide when scrolling down significantly
        else if delta < -30 && offset < -100 {
            updatedVisibility = false
        }
        // Show when scrolling up significantly
        else if delta > 30 {
            updatedVisibility = true
        }

        if let updatedVisibility,
           headerVisible != updatedVisibility || isTabBarVisible != updatedVisibility {
            withAnimation(.easeInOut(duration: 0.25)) {
                headerVisible = updatedVisibility
                isTabBarVisible = updatedVisibility
            }
        }

        isAtTop = offset >= -50
        lastScrollOffset = offset
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                let delay = UInt64(pollInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                await viewModel.checkForNewPosts(
                    minCount: minNewPostsCount,
                    cooldown: toastCooldown,
                    isAtTop: isAtTop
                )
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func handleToastTap(proxy: ScrollViewProxy) {
        viewModel.dismissNewPostsToast()
        Task {
            await viewModel.refreshPosts()
            withAnimation(.easeInOut(duration: 0.25)) {
                headerVisible = true
                isTabBarVisible = true
                proxy.scrollTo(topAnchorId, anchor: .top)
            }
        }
    }
}


#Preview {
    FeedView()
        .environmentObject(FeedViewModel())
        .environmentObject(AuthViewModel())
}
