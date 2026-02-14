import SwiftUI

struct FeedView: View {
    let onProfileTap: () -> Void
    @Binding private var isTabBarVisible: Bool
    @Binding private var scrollToTopSignal: Int
    @Environment(\.floatingActionButtonState) private var fabState
    @EnvironmentObject var viewModel: FeedViewModel
    @State private var headerVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isAtTop = true
    @State private var pollingTask: Task<Void, Never>?
    @State private var measuredHeaderHeight: CGFloat = 140

    private var headerHeight: CGFloat { max(0, measuredHeaderHeight) }
    private let pollInterval: TimeInterval = 90
    private let toastCooldown: TimeInterval = 7 * 60
    private let minNewPostsCount = 7
    private let topAnchorId = "feedTop"
    private let scrollCoordinateSpace = "feedScrollCoordinateSpace"

    init(
        isTabBarVisible: Binding<Bool> = .constant(true),
        scrollToTopSignal: Binding<Int> = .constant(0),
        onProfileTap: @escaping () -> Void = {}
    ) {
        self._isTabBarVisible = isTabBarVisible
        self._scrollToTopSignal = scrollToTopSignal
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
                            if viewModel.showSkeleton {
                                ForEach(0..<6, id: \.self) { index in
                                    PostCardSkeleton(showsMedia: index % 3 != 0)

                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
                                }
                            } else {
                                ProgressView()
                                    .tint(.loopedPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 26)
                            }
                        } else if viewModel.posts.isEmpty {
                            EmptyFeedView()
                        } else {
                            ForEach(viewModel.posts) { post in
                                PostCard(
                                    post: post,
                                    showsCommunityLabel: true,
                                    showsRepostBanner: true,
                                    onUpdate: { updated in
                                        viewModel.updatePost(updated)
                                    },
                                    onDelete: { deleted in
                                        viewModel.removePost(backendId: deleted.backendId)
                                    },
                                    onBlockUser: { blockedUserId in
                                        viewModel.removePosts(authorBackendId: blockedUserId)
                                    },
                                    onBlockPrincipal: { principalId in
                                        viewModel.removePosts(authorPrincipalId: principalId)
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
                                LoopedInlineLoadingIndicator()
                            }
                        }
                    }
                    .background(
                        GeometryReader { geo in
                            Color.loopedClear
                                .onChange(of: geo.frame(in: .named(scrollCoordinateSpace)).minY) { oldValue, newValue in
                                    guard abs(newValue - oldValue) > 0.5 else { return }
                                    handleScroll(newValue)
                                }
                        }
                    )
                }
                .coordinateSpace(name: scrollCoordinateSpace)
                .onChange(of: scrollToTopSignal) { _, _ in
                    scrollToTop(proxy: proxy)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.loopedClear
                        .frame(height: headerHeight)
                        .allowsHitTesting(false)
                }
                .loopedPullToRefresh(
                    isEnabled: !viewModel.isCommunitySearchActive,
                    isAtTop: isAtTop,
                    indicatorTopPadding: headerVisible ? headerHeight + 14 : 16
                ) {
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
            .overlay(alignment: .bottom) {
                if viewModel.isLoadingMore && !viewModel.posts.isEmpty {
                    LoopedInlineLoadingIndicator()
                        .background(Color.loopedBackground.opacity(0.92))
                        .padding(.bottom, isTabBarVisible ? 72 : 12)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
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
            .background(
                GeometryReader { proxy in
                    Color.loopedClear
                        .preference(key: FeedHeaderHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .background(
                Color.loopedBackground
                    .ignoresSafeArea(.all, edges: .top)
                    .allowsHitTesting(false)
            )
            .offset(y: headerVisible ? 0 : -headerHeight)
            .opacity(headerVisible ? 1 : 0)
            .allowsHitTesting(headerVisible)
            .animation(.easeInOut(duration: 0.25), value: headerVisible)
        }
        .background(Color.loopedBackground)
        .navigationBarHidden(true)
        .onPreferenceChange(FeedHeaderHeightPreferenceKey.self) { newValue in
            guard newValue > 0 else { return }
            if abs(newValue - measuredHeaderHeight) > 0.5 {
                measuredHeaderHeight = newValue
            }
        }
        .task {
            await viewModel.loadInitial()
        }
        .onAppear {
            fabState.isHidden = false
            headerVisible = true
            isTabBarVisible = true
            lastScrollOffset = 0
            startPolling()
        }
        .onDisappear {
            withAnimation(.easeInOut(duration: 0.2)) {
                isTabBarVisible = true
            }
            stopPolling()
        }
        .loopedHashtagNavigationHost()
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
            let atTop = offset >= -50
            if atTop != isAtTop {
                isAtTop = atTop
            }
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

        let atTop = offset >= -50
        if atTop != isAtTop {
            isAtTop = atTop
        }
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
            scrollToTop(proxy: proxy)
        }
    }

    private func scrollToTop(proxy: ScrollViewProxy) {
        if !headerVisible || !isTabBarVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                headerVisible = true
                isTabBarVisible = true
            }
        } else {
            headerVisible = true
            isTabBarVisible = true
        }

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(topAnchorId, anchor: .top)
            }
        }
    }
}

private struct FeedHeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 140

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}


#Preview {
    FeedView()
        .environmentObject(FeedViewModel())
        .environmentObject(AuthViewModel())
}
