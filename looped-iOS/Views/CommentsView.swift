import SwiftUI

struct CommentsView: View {
    let post: Post
    let onDismiss: () -> Void
    @EnvironmentObject var commentsManager: CommentsModalManager
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("anonymousMode") private var isAnonymousMode = false
    @State private var commentText: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var selectedHashtag: String?
    @State private var showHashtagFeed = false
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideoUrl: String?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false
    @State private var anonProfileId: Int?

    private var comments: [Comment] {
        commentsManager.currentComments
    }

    private var canComment: Bool {
        guard let communityId = post.communityId else {
            return authViewModel.currentUser?.isVerified == true
        }
        if commentsManager.isLoadingPermissions {
            return false
        }
        if let permissions = commentsManager.communityPermissions {
            return permissions.canPost
        }
        if let community = feedViewModel.followedCommunities.first(where: { $0.id == communityId }) {
            return community.canPost
        }
        return true
    }

    private var postAuthorName: String {
        if post.isAnonymous {
            return "Anonymous"
        }
        return post.authorDisplayName ?? "User"
    }

    private var imageUrls: [String] {
        post.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    threadHeader
                    commentsContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            commentInput
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            setupKeyboardObservers()
            Task { await loadAnonProfileId() }
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .onChange(of: isAnonymousMode) { _, _ in
            Task { await loadAnonProfileId() }
        }
        .onChange(of: commentsManager.editTarget?.backendId) { _, newValue in
            if let newValue, let target = commentsManager.editTarget, target.backendId == newValue {
                commentText = target.content
            } else if commentsManager.editTarget == nil {
                commentText = ""
            }
        }
        .fullScreenCover(isPresented: $showHashtagFeed, onDismiss: {
            selectedHashtag = nil
        }) {
            if let hashtag = selectedHashtag {
                HashtagFeedView(hashtag: hashtag)
                    .environmentObject(commentsManager)
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            FullScreenImageViewer(
                imageUrls: imageUrls,
                initialIndex: selectedImageIndex,
                isPresented: $showImageViewer
            )
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let url = selectedVideoUrl {
                VideoPlayerSheet(videoUrl: url, isPresented: $showVideoPlayer)
            }
        }
    }
}

// MARK: - Subviews
private extension CommentsView {
    var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: { onDismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.loopedTextPrimary)
            }

            Text("\(comments.count) comment\(comments.count == 1 ? "" : "s")")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.loopedBackground)
    }

    var threadHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.loopedTextSecondary.opacity(0.15))
                .overlay(
                    Text(String(postAuthorName.prefix(1)).uppercased())
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                )
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 8) {
                let trimmedContent = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedContent.isEmpty {
                    if trimmedContent.contains("#") {
                        HashtagText(
                            text: trimmedContent,
                            font: .loopedHeadingMedium,
                            textColor: .loopedTextPrimary,
                            hashtagColor: .loopedPrimary,
                            onHashtagTap: handleHashtagTap
                        )
                        .multilineTextAlignment(.leading)
                    } else {
                        Text(trimmedContent)
                            .font(.loopedHeadingMedium)
                            .foregroundColor(.loopedTextPrimary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Text(postAuthorName)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)

                Text(formattedTimestamp(for: post.createdAt))
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)

                if let attachments = post.attachments, !attachments.isEmpty {
                    PostedMediaGrid(
                        attachments: attachments,
                        maxHeight: 240,
                        onImageTap: { url in
                            guard !url.isEmpty, URL(string: url) != nil else { return }
                            if let index = imageUrls.firstIndex(of: url) {
                                selectedImageIndex = index
                            }
                            showImageViewer = true
                        },
                        onVideoTap: { url in
                            guard !url.isEmpty, URL(string: url) != nil else { return }
                            selectedVideoUrl = url
                            showVideoPlayer = true
                        }
                    )
                }
            }
        }
    }

    var commentsContent: some View {
        Group {
            if commentsManager.isLoading && comments.isEmpty {
                ProgressView()
                    .tint(.loopedPrimary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if let error = commentsManager.errorMessage, comments.isEmpty {
                Text(error)
                    .font(.loopedSmallText)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else if comments.isEmpty {
                VStack(spacing: 10) {
                    Text("No comments yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text("Be the first to share your thoughts.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                LazyVStack(spacing: 20) {
                    if let error = commentsManager.errorMessage {
                        Text(error)
                            .font(.loopedSmallText)
                            .foregroundColor(.red)
                    }

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
                            },
                            canManage: { canManage(comment: $0) },
                            onEdit: { target in
                                commentsManager.setEditTarget(target)
                            },
                            onDelete: { target in
                                Task { await commentsManager.deleteComment(target) }
                            },
                            onHashtagTap: handleHashtagTap
                        )
                        .onAppear {
                            Task { await commentsManager.loadMoreIfNeeded(current: comment) }
                        }
                    }

                    if commentsManager.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 12)
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

            if let editTarget = commentsManager.editTarget {
                HStack {
                    Text("Editing your comment")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                    Spacer()
                    Button(action: {
                        commentsManager.clearEditTarget()
                        commentText = ""
                    }) {
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

                    Text(verificationMessage)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.horizontal, 4)
            }

            HStack(alignment: .bottom, spacing: 12) {
                if let imageUrl = authViewModel.currentUser?.profileImageURL,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.loopedTextSecondary.opacity(0.2))
                    }
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.15))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.loopedTextSecondary)
                        )
                        .frame(width: 34, height: 34)
                }

                TextField(inputPlaceholder, text: $commentText, axis: .vertical)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button(action: {
                    Task {
                        guard canComment else { return }
                        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        if commentsManager.editTarget != nil {
                            await commentsManager.editComment(content: trimmed)
                        } else {
                            await commentsManager.postComment(content: trimmed)
                        }
                        commentText = ""
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(
                            commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentsManager.isPosting || !canComment
                            ? .loopedTextSecondary
                            : .loopedPrimary
                        )
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentsManager.isPosting || !canComment)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, max(12, keyboardHeight > 0 ? 8 : 12))
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

    func formattedTimestamp(for date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)

        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60

        if days > 0 {
            return "\(days)d ago"
        } else if hours > 0 {
            return "\(hours)h ago"
        } else if minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }

    func displayName(for comment: Comment) -> String {
        if comment.isAnonymous {
            return "Anonymous"
        }
        return comment.authorDisplayName ?? "User"
    }

    func canManage(comment: Comment) -> Bool {
        guard !comment.isDeleted else { return false }
        if comment.isAnonymous {
            guard isAnonymousMode, let anonProfileId else { return false }
            return comment.authorBackendId == anonProfileId
        }
        guard let currentUserId = authViewModel.currentUser?.backendId else { return false }
        return comment.authorBackendId == currentUserId
    }

    var inputPlaceholder: String {
        commentsManager.editTarget == nil ? "Add a comment..." : "Edit comment..."
    }

    var verificationMessage: String {
        if commentsManager.isLoadingPermissions {
            return "Checking verification..."
        }
        if let permissions = commentsManager.communityPermissions {
            if !permissions.canPost, permissions.requiresVerification {
                return "Verification is required to comment in this community."
            }
            if !permissions.canPost {
                return "You do not have permission to comment in this community."
            }
        }
        return "Verification is required to comment in this community."
    }

    func loadAnonProfileId() async {
        if isAnonymousMode {
            anonProfileId = await AnonService.shared.currentIdentity()?.profileId
        } else {
            anonProfileId = nil
        }
    }

    func handleHashtagTap(_ hashtag: String) {
        let trimmed = hashtag.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHashtag = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard !cleanHashtag.isEmpty else { return }
        selectedHashtag = cleanHashtag
        showHashtagFeed = true
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
