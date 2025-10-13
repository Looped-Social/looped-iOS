import SwiftUI

struct HashtagFeedView: View {
    let hashtag: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var commentsManager: CommentsModalManager
    @StateObject private var viewModel = FeedViewModel()

    // Remove # if present to display
    private var displayHashtag: String {
        hashtag.hasPrefix("#") ? hashtag : "#\(hashtag)"
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
                    // In a real app, filter posts by hashtag
                    // For now, showing all posts as example
                    ForEach(viewModel.posts) { post in
                        PostCard(post: post)

                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.loopedTextSecondary.opacity(0.1))
                    }
                }
            }
            .refreshable {
                await viewModel.loadPosts()
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadPosts()
        }
    }
}

#Preview {
    HashtagFeedView(hashtag: "TGIF")
        .environmentObject(CommentsModalManager())
}
