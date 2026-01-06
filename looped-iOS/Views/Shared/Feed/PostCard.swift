import SwiftUI

struct PostCard: View {
    let post: Post
    let showsCommunityLabel: Bool
    let onBookmarkToggle: ((Bool) -> Void)?
    let onUpdate: ((Post) -> Void)?
    let onDelete: ((Post) -> Void)?
    private let feedService: FeedServiceProtocol
    @State private var isLiked = false
    @State private var isBookmarked = false
    @State private var bookmarkInitialized = false
    @State private var isBookmarkLoading = false
    @State private var isLikeLoading = false
    @State private var showHeartBurst = false
    @State private var heartScale: CGFloat = 0.6
    @State private var heartOpacity: Double = 0
    @State private var showShareSheet = false
    @State private var shareCountOverride: Int?
    @State private var isShareTracking = false
    @State private var selectedImageUrl: String?
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideoUrl: String?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false
    @State private var selectedHashtag: String?
    @State private var showHashtagFeed = false
    @EnvironmentObject var commentsManager: CommentsModalManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showActionMenu = false
    @State private var activeModerationSheet: ModerationSheet?
    @State private var moderationAlertMessage: String?
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    @State private var showEditSheet = false
    @State private var editText = ""
    @State private var isEditing = false
    @State private var editErrorMessage: String?

    private let moderationService: ModerationServiceProtocol = ModerationService()

    init(
        post: Post,
        feedService: FeedServiceProtocol = FeedService(),
        showsCommunityLabel: Bool = false,
        onBookmarkToggle: ((Bool) -> Void)? = nil,
        onUpdate: ((Post) -> Void)? = nil,
        onDelete: ((Post) -> Void)? = nil
    ) {
        self.post = post
        self.feedService = feedService
        self.showsCommunityLabel = showsCommunityLabel
        self.onBookmarkToggle = onBookmarkToggle
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    private var imageUrls: [String] {
        post.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
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

    private var currentShareCount: Int {
        shareCountOverride ?? post.shareCount
    }

    private var displayedReactionCount: Int {
        let base = post.reactionCount
        if isLiked, post.userReaction != .like {
            return base + 1
        }
        return base
    }

    private var displayCommunityText: String? {
        post.authorDisplayCommunity?.displayText
    }

    private var communityContextText: String? {
        guard showsCommunityLabel else { return nil }
        if let name = post.communityName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return "in \(name)"
        }
        if let kind = post.communityKind, kind != .unknown {
            return "in \(kind.rawValue.capitalized)"
        }
        return nil
    }

    private var authorProfileId: Int? {
        post.authorBackendId ?? post.authorId.backendInt
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let authorProfileId {
            NavigationLink(destination: authorProfileDestination(profileId: authorProfileId)) {
                avatarContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            avatarContent
        }
    }

    private var avatarContent: some View {
        Circle()
            .fill(Color.loopedTextSecondary.opacity(0.2))
            .overlay(
                Text(initials(from: post.resolvedAuthorName))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.loopedTextPrimary)
            )
            .frame(width: 40, height: 40)
    }

    @ViewBuilder
    private var authorName: some View {
        if let authorProfileId {
            NavigationLink(destination: authorProfileDestination(profileId: authorProfileId)) {
                Text(post.resolvedAuthorName)
                    .font(.headline)
                    .foregroundColor(post.isAnonymous ? .loopedSecondary : .loopedTextPrimary)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            Text(post.resolvedAuthorName)
                .font(.headline)
                .foregroundColor(post.isAnonymous ? .loopedSecondary : .loopedTextPrimary)
        }
    }

    @ViewBuilder
    private func authorProfileDestination(profileId: Int) -> some View {
        if post.isAnonymous {
            UserProfileView(anonProfileId: profileId)
        } else {
            UserProfileView(userId: profileId)
        }
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                // Header with user info
                HStack(alignment: .top, spacing: 12) {
                    if !post.isAnonymous {
                        authorAvatar
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            // Name and primary community
                            authorName

                            if let displayCommunityText {
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundColor(.loopedTextSecondary)
                                Text(displayCommunityText)
                                    .font(.subheadline)
                                    .foregroundColor(.loopedTextSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            Spacer()

                            // More button
                            Button(action: { showActionMenu = true }) {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.loopedTextSecondary)
                            }
                        }

                        if let communityContextText {
                            Text(communityContextText)
                                .font(.subheadline)
                                .foregroundColor(.loopedTextSecondary)
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
            }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    handleDoubleTapLike()
                }

                // Engagement buttons
                HStack(spacing: 24) {
                    // Like button
                    Button(action: { handleLikeToggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
                                .foregroundColor(isLiked ? .red : .loopedTextSecondary)
                            Text("\(displayedReactionCount)")
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
                            Text("\(post.commentsCount)")
                                .font(.caption)
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }

                    // Share button
                    Button(action: { showShareSheet = true }) {
                        Image("send-icon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 19, height: 19)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    Spacer()

                    // Bookmark button
                    Button(action: { toggleBookmark() }) {
                        Image(isBookmarked ? "saved-icon" : "save-icon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 18, height: 18)
                            .foregroundColor(isBookmarked ? .loopedPrimary : .loopedTextSecondary)
                            .opacity(isBookmarkLoading ? 0.6 : 1)
                    }
                    .disabled(isBookmarkLoading || post.backendId == nil)
                }

                // Timestamp at bottom
                HStack {
                    Text(formattedTimeAgo)
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                    Spacer()
                }
            }

            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.red)
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
                    .allowsHitTesting(false)
            }
        }
        .padding(16)
        .background(Color.loopedBackground)
        .cornerRadius(0)
        .onAppear {
            if !bookmarkInitialized {
                isBookmarked = post.isSaved
                bookmarkInitialized = true
            }
            syncLikeState()
        }
        .onChange(of: post.userReaction) { _, _ in
            syncLikeState()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText]) { completed in
                if completed {
                    trackShare()
                }
            }
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
        .confirmationDialog("Post options", isPresented: $showActionMenu, titleVisibility: .visible) {
            if canEditPost {
                Button("Edit Post") {
                    editText = post.content
                    showEditSheet = true
                }
            }
            if canDeletePost {
                Button("Delete Post", role: .destructive) {
                    Task { await deletePost() }
                }
            }
            if canReportPost {
                Button("Report Post", role: .destructive) {
                    activeModerationSheet = .reportPost
                }
            }
            if canReportUser {
                Button("Report User", role: .destructive) {
                    activeModerationSheet = .reportUser
                }
            }
            if canAppealPostRemoval {
                Button("Appeal Post Removal") {
                    activeModerationSheet = .appealPostRemoval
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(item: $activeModerationSheet) { sheet in
            switch sheet {
            case .reportPost:
                ReportReasonSheet(
                    title: "Report Post",
                    onSubmit: { reason in
                        guard let backendId = post.backendId else {
                            throw ModerationError.missingTarget
                        }
                        _ = try await moderationService.createReport(
                            targetType: "post",
                            targetId: backendId,
                            reason: reason
                        )
                    },
                    onSuccess: { moderationAlertMessage = "Thanks for reporting. We'll review it shortly." }
                )
            case .reportUser:
                ReportReasonSheet(
                    title: "Report User",
                    onSubmit: { reason in
                        guard let backendId = post.authorBackendId else {
                            throw ModerationError.missingTarget
                        }
                        _ = try await moderationService.createReport(
                            targetType: "user",
                            targetId: backendId,
                            reason: reason
                        )
                    },
                    onSuccess: { moderationAlertMessage = "Thanks for reporting. We'll review it shortly." }
                )
            case .appealPostRemoval:
                ModerationReasonSheet(
                    title: "Appeal Post Removal",
                    subtitle: "Tell us why this post should be restored.",
                    placeholder: "Share context or details...",
                    submitTitle: "Submit Appeal",
                    onSubmit: { reason in
                        guard let backendId = post.backendId else {
                            throw ModerationError.missingTarget
                        }
                        _ = try await moderationService.createAppeal(
                            targetType: "post_removal",
                            targetId: backendId,
                            reason: reason
                        )
                    },
                    onSuccess: { moderationAlertMessage = "Appeal submitted. We'll review it soon." }
                )
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditPostSheet(
                text: $editText,
                isSaving: isEditing,
                onCancel: { showEditSheet = false },
                onSave: { Task { await updatePost() } }
            )
        }
        .alert(
            "Thanks",
            isPresented: Binding(
                get: { moderationAlertMessage != nil },
                set: { if !$0 { moderationAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(moderationAlertMessage ?? "")
        }
        .alert(
            "Couldn't delete post",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
        .alert(
            "Couldn't update post",
            isPresented: Binding(
                get: { editErrorMessage != nil },
                set: { if !$0 { editErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(editErrorMessage ?? "")
        }
    }

    private var shareText: String {
        "\(post.resolvedAuthorName) posted on Looped:\n\n\(post.content)"
    }

    private func trackShare() {
        guard let postId = post.backendId, !isShareTracking else { return }
        isShareTracking = true
        Task {
            defer { isShareTracking = false }
            do {
                let response = try await feedService.sharePost(postId: postId)
                shareCountOverride = response.shareCount
            } catch {
                // TODO: surface error to user once we add toast system
            }
        }
    }

    private func toggleBookmark() {
        guard let postId = post.backendId, !isBookmarkLoading else { return }
        isBookmarkLoading = true
        Task {
            defer { isBookmarkLoading = false }
            do {
                if isBookmarked {
                    let removed = try await feedService.removeSavedPost(
                        postId: postId,
                        communityId: post.communityId
                    )
                    if removed {
                        isBookmarked = false
                        onBookmarkToggle?(false)
                    }
                } else {
                    let saved = try await feedService.savePost(
                        postId: postId,
                        communityId: post.communityId
                    )
                    if saved {
                        isBookmarked = true
                        onBookmarkToggle?(true)
                    }
                }
            } catch {
                // TODO: surface error to user once we add toast system
            }
        }
    }

    private func deletePost() async {
        guard let postId = post.backendId, !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            let response = try await feedService.deletePost(
                postId: postId,
                communityId: post.communityId,
                asAnon: post.isAnonymous
            )
            if response.deleted {
                onDelete?(post)
            } else {
                deleteErrorMessage = "Post could not be deleted."
            }
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }

    private func updatePost() async {
        guard let postId = post.backendId, !isEditing else { return }
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isEditing = true
        defer { isEditing = false }
        do {
            let updated = try await feedService.updatePost(
                postId: postId,
                content: trimmed,
                isAnonymous: post.isAnonymous,
                communityId: post.communityId
            )
            onUpdate?(updated)
            showEditSheet = false
        } catch {
            editErrorMessage = error.localizedDescription
        }
    }

    private func initials(from name: String?) -> String {
        guard let name = name, let first = name.split(separator: " ").first?.first else {
            return "U"
        }
        return String(first).uppercased()
    }

    private func handleLikeToggle() {
        guard let postId = post.backendId else { return }
        if isLiked { return }
        isLiked = true
        triggerHeartBurst()
        Task {
            guard !isLikeLoading else { return }
            isLikeLoading = true
            defer { isLikeLoading = false }
            do {
                let response = try await feedService.reactToPost(
                    postId: postId,
                    communityId: post.communityId,
                    reaction: .like
                )
                let updated = post.updating(
                    reactionCount: response.likesCount,
                    userReaction: .some(.like),
                    updatedAt: Date()
                )
                onUpdate?(updated)
            } catch {
                isLiked = false
            }
        }
    }

    private func handleDoubleTapLike() {
        if isLiked {
            triggerHeartBurst()
        } else {
            handleLikeToggle()
        }
    }

    private func syncLikeState() {
        isLiked = post.userReaction == .like
    }

    private func triggerHeartBurst() {
        showHeartBurst = true
        heartScale = 0.6
        heartOpacity = 0

        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            heartScale = 1.2
            heartOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.25).delay(0.2)) {
            heartScale = 1.4
            heartOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showHeartBurst = false
            heartScale = 0.6
            heartOpacity = 0
        }
    }
}

private extension PostCard {
    enum ModerationSheet: String, Identifiable {
        case reportPost
        case reportUser
        case appealPostRemoval

        var id: String { rawValue }
    }

    enum ModerationError: LocalizedError {
        case missingTarget

        var errorDescription: String? {
            "This action isn't available right now."
        }
    }

    var canReportPost: Bool {
        post.backendId != nil
    }

    var canReportUser: Bool {
        guard let authorId = post.authorBackendId else { return false }
        if let currentUser = authViewModel.currentUser, currentUser.backendId == authorId {
            return false
        }
        return true
    }

    var canDeletePost: Bool {
        guard post.backendId != nil else { return false }
        guard let authorId = post.authorBackendId else { return false }
        guard let currentUser = authViewModel.currentUser else { return false }
        return currentUser.backendId == authorId
    }

    var canEditPost: Bool {
        canDeletePost
    }

    var canAppealPostRemoval: Bool {
        guard let currentUser = authViewModel.currentUser else { return false }
        return post.backendId != nil && post.authorBackendId == currentUser.backendId
    }
}

struct EditPostSheet: View {
    @Binding var text: String
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    private let characterLimit = 280

    private var remainingCharacters: Int {
        characterLimit - text.count
    }

    private var isValid: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && text.count <= characterLimit
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit your post")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextSecondary)

                TextEditor(text: $text)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .padding(12)
                    .frame(minHeight: 140)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Spacer()
                    Text("\(remainingCharacters)")
                        .font(.loopedSmallText)
                        .foregroundColor(remainingCharacters < 20 ? .red : .loopedTextSecondary)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.loopedPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { onSave() }
                        .disabled(!isValid || isSaving)
                        .foregroundColor((isValid && !isSaving) ? .loopedPrimary : .loopedTextSecondary)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
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
        .environmentObject(AuthViewModel())
}
