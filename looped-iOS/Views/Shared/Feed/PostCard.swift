import SwiftUI

struct PostCard: View {
    let post: Post
    @State private var isLiked = false
    @State private var isBookmarked = false
    @State private var showShareSheet = false
    @State private var selectedImageUrl: String?
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideoUrl: String?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false
    @State private var selectedHashtag: String?
    @State private var showHashtagFeed = false
    @EnvironmentObject var commentsManager: CommentsModalManager

    private var imageUrls: [String] {
        post.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    private var commentCount: Int {
        MockComments.getCommentCount(for: post.id)
    }

    private var formattedTimeAgo: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(post.createdAt)

        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            return "just now"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with user info
            HStack(alignment: .top, spacing: 12) {
                // Avatar (hidden for anonymous posts)
                if !post.isAnonymous {
                    if let userProfile = MockUserProfiles.getUserProfile(byId: post.authorId) {
                        NavigationLink(destination: UserProfileView(userProfile: userProfile)) {
                            AsyncImage(url: URL(string: "https://via.placeholder.com/40")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.loopedTextSecondary.opacity(0.3))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Fallback if profile not found
                        AsyncImage(url: URL(string: "https://via.placeholder.com/40")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.loopedTextSecondary.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        // Name and handle
                        Text(post.isAnonymous ? "Anonymous" : (post.authorDisplayName ?? "User"))
                            .font(.headline)
                            .foregroundColor(post.isAnonymous ? .loopedSecondary : .loopedTextPrimary)

                        if !post.isAnonymous {
                            Text("@\(post.authorDisplayName?.lowercased().replacingOccurrences(of: " ", with: "") ?? "user")")
                                .font(.subheadline)
                                .foregroundColor(.loopedTextSecondary)
                        }

                        Spacer()

                        // More button
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }

                    // Job title and company (only for non-anonymous posts)
                    if !post.isAnonymous {
                        HStack(spacing: 4) {
                            Text("Product Designer @ \(post.company)")
                                .font(.subheadline)
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }
                }
            }
            
            // Post content with tappable hashtags
            if !post.content.isEmpty {
                HashtagText(
                    text: post.content,
                    font: .body,
                    textColor: .loopedTextPrimary,
                    hashtagColor: .loopedPrimary
                ) { hashtag in
                    selectedHashtag = hashtag
                    showHashtagFeed = true
                }
                .multilineTextAlignment(.leading)
            }

            // Media attachments
            if let attachments = post.attachments, !attachments.isEmpty {
                PostedMediaGrid(
                    attachments: attachments,
                    maxHeight: 350,
                    onImageTap: { url in
                        guard !url.isEmpty, URL(string: url) != nil else { return }
                        // Find the index of the tapped image among all images
                        if let index = imageUrls.firstIndex(of: url) {
                            selectedImageIndex = index
                        }
                        selectedImageUrl = url
                        showImageViewer = true
                    },
                    onVideoTap: { url in
                        guard !url.isEmpty, URL(string: url) != nil else { return }
                        selectedVideoUrl = url
                        showVideoPlayer = true
                    }
                )
                .padding(.top, 8)
            }

            // Engagement buttons
            HStack(spacing: 24) {
                // Like button
                Button(action: { isLiked.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(isLiked ? .red : .loopedTextSecondary)
                        Text("\(post.reactionCount + (isLiked ? 1 : 0))")
                            .font(.caption)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }

                // Comment button
                Button(action: {
                    commentsManager.showComments(for: post)
                }) {
                    HStack(spacing: 4) {
                        Image("comment-icon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 18, height: 18)
                            .foregroundColor(.loopedTextSecondary)
                        Text("\(commentCount)")
                            .font(.caption)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }

                // Share button
                Button(action: { showShareSheet = true }) {
                    HStack(spacing: 4) {
                        Image("send-icon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 19, height: 19)
                            .foregroundColor(.loopedTextSecondary)
                        Text("67")
                            .font(.caption)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }

                Spacer()

                // Bookmark button
                Button(action: { isBookmarked.toggle() }) {
                    HStack(spacing: 4) {
                        Image("save-icon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 18, height: 18)
                            .foregroundColor(isBookmarked ? .loopedPrimary : .loopedTextSecondary)
                        Text("999")
                            .font(.caption)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
            }

            // Timestamp at bottom
            HStack {
                Text(formattedTimeAgo)
                    .font(.subheadline)
                    .foregroundColor(.loopedTextSecondary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color.loopedBackground)
        .cornerRadius(0)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
        .fullScreenCover(isPresented: $showImageViewer, onDismiss: {
            selectedImageUrl = nil
        }) {
            if !imageUrls.isEmpty {
                FullScreenImageViewer(
                    imageUrls: imageUrls,
                    initialIndex: selectedImageIndex,
                    isPresented: $showImageViewer
                )
            } else {
                Color.black.ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                            Text("No images available")
                                .foregroundColor(.white.opacity(0.7))
                            Button("Close") {
                                showImageViewer = false
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                        }
                    )
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer, onDismiss: {
            selectedVideoUrl = nil
        }) {
            if let videoUrl = selectedVideoUrl, !videoUrl.isEmpty, URL(string: videoUrl) != nil {
                VideoPlayerSheet(videoUrl: videoUrl, isPresented: $showVideoPlayer)
            } else {
                Color.black.ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Invalid video URL")
                                .foregroundColor(.white.opacity(0.7))
                            Button("Close") {
                                showVideoPlayer = false
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                        }
                    )
            }
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let hashtag = selectedHashtag {
                        HashtagFeedView(hashtag: hashtag)
                            .environmentObject(commentsManager)
                    }
                },
                isActive: $showHashtagFeed,
                label: { EmptyView() }
            )
            .hidden()
        )
    }

    private var shareText: String {
        let author = post.isAnonymous ? "Anonymous" : (post.authorDisplayName ?? "Someone")
        return "\(author) posted on Looped:\n\n\(post.content)"
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let samplePost = Post(
        id: UUID(),
        content: "Excited to share my latest project, a redesign of our user onboarding flow. Focused on simplicity and clarity, resulting in a 20% increase in user retention. Check it out and let me know your thoughts!",
        authorId: UUID(),
        authorDisplayName: "Sarah Chen",
        company: "Looped",
        isAnonymous: true,
        reactionCount: 188,
        userReaction: nil,
        attachments: nil,
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: Date().addingTimeInterval(-86400)
    )

    PostCard(post: samplePost)
        .padding()
        .background(Color.loopedBackground)
        .environmentObject(CommentsModalManager())
}
