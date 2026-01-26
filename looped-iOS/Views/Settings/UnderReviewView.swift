import SwiftUI

struct UnderReviewView: View {
    @StateObject private var viewModel = UnderReviewViewModel()
    @StateObject private var commentsManager = CommentsModalManager()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var isAtTop = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ProgressView()
                        .tint(.loopedPrimary)
                        .padding(.top, 28)
                        .frame(maxWidth: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.posts.isEmpty {
                    Text(error)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedError)
                        .padding(.top, 28)
                        .frame(maxWidth: .infinity)
                } else if viewModel.posts.isEmpty {
                    emptyState
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity)
                    if viewModel.hasMore {
                        Button("Load older posts") {
                            Task { await viewModel.loadMore() }
                        }
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedPrimary)
                        .padding(.top, 16)
                    }
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
                                viewModel.removePost(deleted)
                            }
                        )

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.loopedTextSecondary.opacity(0.1))
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(.loopedPrimary)
                            .padding(.vertical, 16)
                    } else if viewModel.hasMore {
                        Button("Load more") {
                            Task { await viewModel.loadMore() }
                        }
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedPrimary)
                        .padding(.vertical, 16)
                    }
                }
            }
            .background(
                GeometryReader { geo in
                    Color.loopedClear
                        .onChange(of: geo.frame(in: .global).minY) { _, newValue in
                            isAtTop = newValue >= -20
                        }
                }
            )
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Under review")
        .navigationBarTitleDisplayMode(.inline)
        .environmentObject(commentsManager)
        .task {
            await viewModel.loadInitial(fallbackUserId: authViewModel.currentUser?.backendId)
        }
        .loopedPullToRefresh(isAtTop: isAtTop) {
            await viewModel.refresh()
        }
    }
}

private extension UnderReviewView {
    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.loopedCustom(.semibold, size: 36))
                .foregroundColor(.loopedTextSecondary.opacity(0.7))
                .padding(.bottom, 2)

            Text("Nothing under review")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Text("Posts that are being reviewed will show up here.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
}

#Preview {
    NavigationView {
        UnderReviewView()
            .environmentObject(AuthViewModel())
    }
}
