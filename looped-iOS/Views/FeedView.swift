import SwiftUI

struct FeedView: View {
    let onProfileTap: () -> Void
    @EnvironmentObject var viewModel: FeedViewModel
    @State private var headerVisible = true
    @State private var lastScrollOffset: CGFloat = 0

    private let headerHeight: CGFloat = 140

    init(onProfileTap: @escaping () -> Void = {}) {
        self.onProfileTap = onProfileTap
    }

    var body: some View {
        ZStack(alignment: .top) {

            // Simple native ScrollView with ScrollViewReader
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
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
                                PostCard(post: post)
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
                            Color.clear
                                .onChange(of: geo.frame(in: .global).minY) { _, newValue in
                                    handleScroll(newValue)
                                }
                        }
                    )
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: headerHeight)
                }
                .refreshable {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        headerVisible = true
                    }
                    await viewModel.loadInitial()
                }
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

        lastScrollOffset = offset
    }
}


#Preview {
    FeedView()
        .environmentObject(FeedViewModel())
}
