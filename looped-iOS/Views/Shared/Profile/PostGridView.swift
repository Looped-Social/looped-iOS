import SwiftUI

/// A 2-column grid view for displaying posts (Instagram/TikTok style)
/// Used for user posts, liked posts, and saved posts
struct PostGridView: View {
    let posts: [Post]
    let onPostTap: (Post) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            if posts.isEmpty {
                EmptyPostsView()
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(posts) { post in
                        PostGridCell(post: post)
                            .onTapGesture {
                                onPostTap(post)
                            }
                    }
                }
            }
        }
        .background(Color.loopedBackground)
    }
}

// MARK: - Post Grid Cell
struct PostGridCell: View {
    let post: Post

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Background based on content type
                if let firstAttachment = post.attachments?.first {
                    // Show first media attachment
                    AsyncImage(url: URL(string: firstAttachment.type == .video ? (firstAttachment.thumbnailUrl ?? firstAttachment.url) : firstAttachment.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.loopedMutedBackground)
                            .overlay(ProgressView())
                    }

                    // Video indicator
                    if firstAttachment.type == .video {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "play.fill")
                                    .font(.loopedCustom(size: 12))
                                    .foregroundColor(.loopedWhite)
                                    .padding(6)
                                    .background(Color.loopedBlack.opacity(0.6))
                                    .clipShape(Circle())
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                } else {
                    // Text-only post - show miniature post card
                    MiniaturePostCard(post: post, size: geometry.size.width)
                }

                // Engagement indicator overlay (for media posts)
                if post.attachments?.first != nil && post.reactionCount > 0 {
                    VStack {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.loopedCustom(size: 10))
                                    .foregroundColor(.loopedError)
                                Text("\(post.reactionCount)")
                                    .font(.loopedCustom(.medium, size: 10))
                                    .foregroundColor(.loopedWhite)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.loopedBlack.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Miniature Post Card (for text-only posts)
struct MiniaturePostCard: View {
    let post: Post
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Mini header
            HStack(spacing: 6) {
                // Small avatar circle
                ProfileAvatarView(
                    imageURL: post.authorProfileImageURL,
                    size: 16,
                    iconScale: 0.5,
                    variant: post.isAnonymous ? .anonymous : .standard
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.resolvedAuthorName)
                        .font(.loopedCustom(.semibold, size: 9))
                        .foregroundColor(post.isAnonymous ? .loopedSecondary : .loopedTextPrimary)
                        .lineLimit(1)
                }

                Spacer()
            }

            // Post content
            if let poll = post.poll {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.loopedCustom(.semibold, size: 8))
                        .foregroundColor(.loopedPrimary)
                    Text("Poll")
                        .font(.loopedCustom(.semibold, size: 8))
                        .foregroundColor(.loopedPrimary)
                    Spacer()
                }

                Text(poll.question)
                    .font(.loopedCustom(size: 8))
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LinkifiedText(
                    post.content,
                    font: .loopedCustom(size: 8),
                    textColor: .loopedTextPrimary,
                    linkColor: .loopedPrimary
                )
                .lineLimit(8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            // Mini engagement row
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Image(systemName: "heart")
                        .font(.loopedCustom(size: 8))
                        .foregroundColor(.loopedTextSecondary)
                    Text("\(post.reactionCount)")
                        .font(.loopedCustom(size: 7))
                        .foregroundColor(.loopedTextSecondary)
                }

                HStack(spacing: 2) {
                    Image(systemName: "bubble.left")
                        .font(.loopedCustom(size: 8))
                        .foregroundColor(.loopedTextSecondary)
                    Text("\(post.commentsCount)")
                        .font(.loopedCustom(size: 7))
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()
            }
        }
        .padding(8)
        .background(Color.loopedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Empty State
struct EmptyPostsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.loopedCustom(size: 48))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No posts yet")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Grid with posts") {
    PostGridView(posts: MockPosts.getRecentPosts().prefix(6).map { $0 }) { _ in }
}

#Preview("Empty grid") {
    PostGridView(posts: []) { _ in }
}
