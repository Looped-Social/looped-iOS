import SwiftUI

struct FeedView: View {
    let onMenuToggle: () -> Void
    let onProfileTap: () -> Void
    @EnvironmentObject var viewModel: FeedViewModel
    @State private var isHeaderVisible = true
    @State private var isRefreshing = false

    init(onMenuToggle: @escaping () -> Void = {}, onProfileTap: @escaping () -> Void = {}) {
        self.onMenuToggle = onMenuToggle
        self.onProfileTap = onProfileTap
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header and tabs with slide animation
            VStack(spacing: 0) {
                // Custom header
                FeedHeader(onMenuToggle: onMenuToggle, onProfileTap: onProfileTap)

                // Tab and filter section
                FeedTabs()
            }
            .background(Color.loopedBackground.ignoresSafeArea(.all, edges: .top))
            .offset(y: isHeaderVisible ? 0 : -200)
            .opacity(isHeaderVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: isHeaderVisible)
            .clipped() // This ensures content outside bounds is hidden

            // Feed content with Lottie-style refresh
            PullToRefreshScrollView(
                options: PullToRefreshOptions(
                    threshold: 80,
                    animationDuration: 0.3,
                    hapticFeedback: true
                ),
                isRefreshing: $isRefreshing,
                onRefresh: {
                    await viewModel.loadPosts()
                },
                onScrollChange: { scrollDelta in
                    handleScrollChange(scrollDelta)
                }
            ) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.posts) { post in
                        PostCard(post: post)

                        // Separator line
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.loopedTextSecondary.opacity(0.1))
                    }
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadPosts()
        }
    }
    
    private func handleScrollChange(_ scrollDelta: CGFloat) {
        let scrollThreshold: CGFloat = 20
        
        DispatchQueue.main.async {
            // Only change visibility if scroll distance is significant
            if abs(scrollDelta) > scrollThreshold {
                if scrollDelta > 0 && !isHeaderVisible {
                    // Scrolling up - show header
                    isHeaderVisible = true
                } else if scrollDelta < 0 && isHeaderVisible {
                    // Scrolling down - hide header
                    isHeaderVisible = false
                }
            }
        }
    }
}


#Preview {
    FeedView()
        .environmentObject(FeedViewModel())
}