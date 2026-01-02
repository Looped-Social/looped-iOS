import SwiftUI

struct HashtagFeedView: View {
    let hashtag: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var commentsManager: CommentsModalManager
    @StateObject private var viewModel: HashtagFeedViewModel

    // Remove # if present to display
    private var displayHashtag: String {
        hashtag.hasPrefix("#") ? hashtag : "#\(hashtag)"
    }

    init(hashtag: String) {
        self.hashtag = hashtag
        _viewModel = StateObject(wrappedValue: HashtagFeedViewModel(hashtag: hashtag))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Simple header with back button and hashtag
            HStack(spacing: 12) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)
                }

                Text(displayHashtag)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.loopedPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Color.loopedBackground)

            // Feed of posts with this hashtag
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.posts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "number")
                                .font(.system(size: 44))
                                .foregroundColor(.loopedTextSecondary.opacity(0.5))
                            Text("No posts for \(displayHashtag)")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                            Text("Be the first to start the conversation")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.posts) { post in
                            PostCard(post: post, onDelete: { deleted in
                                viewModel.removePost(backendId: deleted.backendId)
                            })
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
        .task {
            await viewModel.loadInitial()
        }
    }
}

#Preview {
    HashtagFeedView(hashtag: "TGIF")
        .environmentObject(CommentsModalManager())
        .environmentObject(AuthViewModel())
}
