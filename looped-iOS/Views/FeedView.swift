import SwiftUI

struct FeedView: View {
    let onProfileTap: () -> Void
    @EnvironmentObject var viewModel: FeedViewModel
    @State private var headerVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isAtTop = true
    @State private var pollingTask: Task<Void, Never>?

    private let headerHeight: CGFloat = 140
    private let pollInterval: TimeInterval = 90
    private let toastCooldown: TimeInterval = 7 * 60
    private let minNewPostsCount = 7
    private let topAnchorId = "feedTop"

    init(onProfileTap: @escaping () -> Void = {}) {
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
                    communities: viewModel.followedCommunities,
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
            lastScrollOffset = 0
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }


    private func handleScroll(_ offset: CGFloat) {
        let delta = offset - lastScrollOffset

        // Show header when near top
        if offset >= -50 {
            withAnimation(.easeInOut(duration: 0.25)) {
                headerVisible = true
            }
        }
        // Hide when scrolling down significantly
        else if delta < -30 && offset < -100 {
            withAnimation(.easeInOut(duration: 0.25)) {
                headerVisible = false
            }
        }
        // Show when scrolling up significantly
        else if delta > 30 {
            withAnimation(.easeInOut(duration: 0.25)) {
                headerVisible = true
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
