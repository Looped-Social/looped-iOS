import SwiftUI

struct CommentsView: View {
    let post: Post
    let onDismiss: () -> Void
    @EnvironmentObject var commentsManager: CommentsModalManager
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var commentText: String = ""
    @State private var keyboardHeight: CGFloat = 0

    private var comments: [Comment] {
        commentsManager.currentComments
    }

    private var canComment: Bool {
        guard let communityId = post.communityId else {
            return authViewModel.currentUser?.isVerified == true
        }
        return feedViewModel.followedCommunities.first(where: { $0.id == communityId })?.canPost == true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(comments.count) comment\(comments.count == 1 ? "" : "s")")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                Button(action: { onDismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.loopedBackground)

            // Divider
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.loopedTextSecondary.opacity(0.1))

            commentsList

            Spacer()

            // Input area - TikTok style at bottom
            VStack(spacing: 0) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.loopedTextSecondary.opacity(0.1))

                commentInput
            }
        }
        .background(Color.loopedBackground)
        .onAppear {
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
}

// MARK: - Subviews
private extension CommentsView {
    var commentsList: some View {
        Group {
            if commentsManager.isLoading && comments.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(.loopedPrimary)
                    Spacer()
                }
            } else if comments.isEmpty {
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.loopedTextSecondary.opacity(0.3))

                    Text("No comments yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)

                    Text("Be the first to share your thoughts!")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(comments) { comment in
                            let thread = commentsManager.threadState(for: comment)
                            CommentRow(
                                comment: comment,
                                replies: thread.isExpanded ? thread.replies : [],
                                isExpanded: thread.isExpanded,
                                isLoadingReplies: thread.isLoading,
                                isLoadingMoreReplies: thread.isLoadingMore,
                                hasMoreReplies: thread.nextCursor != nil,
                                onReply: { commentsManager.setReplyTarget($0) },
                                onToggleReplies: { tapped in
                                    Task { await commentsManager.toggleReplies(for: tapped) }
                                },
                                onLoadMoreReplies: { tapped in
                                    Task { await commentsManager.loadMoreRepliesIfNeeded(for: tapped) }
                                },
                                onLike: { tappedComment in
                                    Task {
                                        await commentsManager.toggleLike(for: tappedComment)
                                    }
                                }
                            )
                            .onAppear {
                                Task { await commentsManager.loadMoreIfNeeded(current: comment) }
                            }

                            // Divider between comments
                            if comment.id != comments.last?.id {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.loopedTextSecondary.opacity(0.05))
                                    .padding(.horizontal, 16)
                            }
                        }

                        if commentsManager.isLoadingMore {
                            ProgressView()
                                .padding(.vertical, 16)
                        }

                        // Bottom padding to account for input area
                        Rectangle()
                            .frame(height: 80)
                            .foregroundColor(.clear)
                    }
                }
            }
        }
    }

    var commentInput: some View {
        VStack(spacing: 8) {
            if let replyTarget = commentsManager.replyTarget {
                HStack {
                    Text("Replying to \(displayName(for: replyTarget))")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                    Spacer()
                    Button(action: { commentsManager.clearReplyTarget() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !canComment {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.loopedSecondary)

                    Text("Verification is required to comment in this community.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.horizontal, 4)
            }

            HStack(alignment: .bottom, spacing: 12) {
                // User avatar placeholder
                AsyncImage(url: URL(string: "https://via.placeholder.com/32")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.3))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                // Text input
                HStack {
                    TextField("Add comment...", text: $commentText, axis: .vertical)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .background(Color.loopedMutedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .disabled(!canComment)

                Button(action: {
                    Task {
                        guard canComment else { return }
                        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        await commentsManager.postComment(content: trimmed)
                        commentText = ""
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(
                            commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentsManager.isPosting || !canComment
                            ? .loopedTextSecondary
                            : .loopedPrimary
                        )
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentsManager.isPosting || !canComment)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, max(12, keyboardHeight > 0 ? 0 : 12))
            .background(Color.loopedBackground)
        }
    }
}

// MARK: - Keyboard helpers
private extension CommentsView {
    func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }

    func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    func displayName(for comment: Comment) -> String {
        if comment.isAnonymous {
            return "Anonymous"
        }
        return comment.authorDisplayName ?? "User"
    }
}

#Preview {
    let samplePost = Post(
        id: UUID(),
        content: "Excited to share my latest project, a redesign of our user onboarding flow.",
        authorId: UUID(),
        authorDisplayName: "Sarah Chen",
        company: "Looped",
        isAnonymous: false,
        reactionCount: 188,
        commentsCount: 4,
        shareCount: 0,
        userReaction: nil,
        attachments: nil,
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: Date().addingTimeInterval(-86400)
    )

    let manager = CommentsModalManager()
    manager.currentPost = samplePost
    manager.currentComments = MockComments.getCommentsForPost(samplePost.id)

    return CommentsView(post: samplePost) {}
        .environmentObject(manager)
        .environmentObject(FeedViewModel())
        .environmentObject(AuthViewModel())
}
