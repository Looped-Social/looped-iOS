import SwiftUI

struct HashtagFeedView: View {
    enum PresentationStyle {
        case overlay
        case navigation
    }

    let hashtag: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var commentsManager: CommentsModalManager
    @StateObject private var viewModel: HashtagFeedViewModel
    let presentationStyle: PresentationStyle

    // Remove # if present to display
    private var displayHashtag: String {
        hashtag.hasPrefix("#") ? hashtag : "#\(hashtag)"
    }

    init(hashtag: String, presentationStyle: PresentationStyle = .navigation) {
        self.hashtag = hashtag
        self.presentationStyle = presentationStyle
        _viewModel = StateObject(wrappedValue: HashtagFeedViewModel(hashtag: hashtag))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Feed of posts with this hashtag
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.posts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "number")
                                .font(.loopedCustom(size: 44))
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
        .navigationBarHidden(presentationStyle == .overlay)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .modifier(HashtagPresentationModifier(style: presentationStyle, onDismiss: { dismiss() }))
        .task {
            await viewModel.loadInitial()
        }
    }

    @ViewBuilder
    private var header: some View {
        switch presentationStyle {
        case .overlay:
            HStack(spacing: 12) {
                LoopedBackButton(action: { dismiss() }, usesHaptics: true)

                Text(displayHashtag)
                    .font(.loopedCustom(.bold, size: 32))
                    .foregroundColor(.loopedPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Color.loopedBackground)
        case .navigation:
            HStack(spacing: 12) {
                Text(displayHashtag)
                    .font(.loopedCustom(.bold, size: 32))
                    .foregroundColor(.loopedPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .background(Color.loopedBackground)
        }
    }
}

private struct HashtagPresentationModifier: ViewModifier {
    let style: HashtagFeedView.PresentationStyle
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        switch style {
        case .overlay:
            content.edgeSwipeToDismiss { onDismiss() }
        case .navigation:
            content
        }
    }
}

#Preview {
    HashtagFeedView(hashtag: "TGIF")
        .environmentObject(CommentsModalManager())
        .environmentObject(AuthViewModel())
}
