import SwiftUI

struct FeedView: View {
    let onMenuToggle: () -> Void
    let onProfileTap: () -> Void
    @EnvironmentObject var viewModel: FeedViewModel
    @State private var headerVisible = true
    @State private var lastScrollOffset: CGFloat = 0

    private let headerHeight: CGFloat = 140

    init(onMenuToggle: @escaping () -> Void = {}, onProfileTap: @escaping () -> Void = {}) {
        self.onMenuToggle = onMenuToggle
        self.onProfileTap = onProfileTap
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Simple native ScrollView with ScrollViewReader
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Spacer for header
                        Color.clear
                            .frame(height: headerHeight)
                            .id("top")

                        ForEach(viewModel.posts) { post in
                            PostCard(post: post)

                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.loopedTextSecondary.opacity(0.1))
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
                .refreshable {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        headerVisible = true
                    }
                    await viewModel.loadPosts()
                }
            }

            // Fixed header
            VStack(spacing: 0) {
                FeedHeader(onMenuToggle: onMenuToggle, onProfileTap: onProfileTap)
                FeedTabs()
            }
            .background(Color.loopedBackground.ignoresSafeArea(.all, edges: .top))
            .offset(y: headerVisible ? 0 : -headerHeight)
            .opacity(headerVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: headerVisible)
            .clipped()
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadPosts()
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