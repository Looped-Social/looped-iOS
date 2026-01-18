import SwiftUI

struct SearchPostsFeedView: View {
    let query: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var commentsManager: CommentsModalManager
    @StateObject private var viewModel: SearchPostsFeedViewModel

    private var displayQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(query: String) {
        self.query = query
        _viewModel = StateObject(wrappedValue: SearchPostsFeedViewModel(query: query))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.posts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.loopedCustom(size: 44))
                                .foregroundColor(.loopedTextSecondary.opacity(0.5))
                            Text("No posts found")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                            Text("Try a different search term")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(.top, 60)
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
                                Task { await viewModel.loadMoreIfNeeded(currentPost: post) }
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
            }
            .refreshable {
                await viewModel.loadPosts(reset: true)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .edgeSwipeToDismiss {
            dismiss()
        }
        .task {
            await viewModel.loadInitial()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            LoopedBackButton(action: { dismiss() }, usesHaptics: true)

            Text(displayQuery)
                .font(.loopedCustom(.bold, size: 32))
                .foregroundColor(.loopedPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.loopedBackground)
    }
}

#Preview {
    SearchPostsFeedView(query: "big thing going on in chapel hill and this is a super long query that should truncate")
        .environmentObject(CommentsModalManager())
        .environmentObject(AuthViewModel())
}
