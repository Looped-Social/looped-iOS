import SwiftUI
import Foundation
import UIKit

struct CommentsView: View {
    enum PresentationStyle {
        case overlay
        case navigation
    }

    let post: Post
    let onDismiss: () -> Void
    let presentationStyle: PresentationStyle
    @EnvironmentObject var commentsManager: CommentsModalManager
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("anonymousMode") private var isAnonymousMode = false
    @State private var commentText: String = ""
    @State private var selectedMedia: [LocalMediaItem] = []
    @State private var keyboardHeight: CGFloat = 0
    @State private var selectedHashtag: String?
    @State private var showHashtagFeed = false
    @State private var selectedImageIndex: Int = 0
    @State private var showImageViewer = false
    @State private var selectedVideo: VideoSelection?
    @State private var anonProfileId: Int?
    @State private var pendingFocusCommentId: Int?
    @State private var showMediaPicker = false
    @State private var showCamera = false
    @State private var keyboardWillShowObserver: NSObjectProtocol?
    @State private var keyboardWillHideObserver: NSObjectProtocol?
    @FocusState private var isCommentFieldFocused: Bool
    @State private var isJoiningSpecialization = false

    private let communityService: CommunityServiceProtocol = CommunityService()

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

    private var joinIsRequired: Bool {
        guard let permissions = commentsManager.communityPermissions else { return false }
        return permissions.requiresJoin && !permissions.canPost
    }

    private var postAuthorName: String {
        post.resolvedAuthorName
    }

    private var imageUrls: [String] {
        post.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    private var titleText: String {
        "\(comments.count) comment\(comments.count == 1 ? "" : "s")"
    }

	    @ViewBuilder
	    private var commentsScrollView: some View {
	        if presentationStyle == .navigation {
	            ScrollView {
	                VStack(alignment: .leading, spacing: 0) {
	                    threadHeader
	                    Rectangle()
	                        .frame(height: 1)
	                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
	                        .padding(.vertical, 16)
	                    commentsContent
	                }
	                .padding(.horizontal, 20)
	                .padding(.top, 16)
	                .padding(.bottom, 24)
            }
		            .modifier(CommentsKeyboardDismissalModifier(onDismiss: dismissKeyboard))
	        } else {
	            ScrollView {
	                VStack(alignment: .leading, spacing: 0) {
	                    threadHeader
	                    Rectangle()
	                        .frame(height: 1)
	                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
	                        .padding(.vertical, 16)
	                    commentsContent
	                }
	                .padding(.horizontal, 20)
	                .padding(.top, 16)
	                .padding(.bottom, 24)
            }
		            .modifier(CommentsKeyboardDismissalModifier(onDismiss: dismissKeyboard))
        }
    }

    init(
        post: Post,
        presentationStyle: PresentationStyle = .overlay,
        onDismiss: @escaping () -> Void
    ) {
        self.post = post
        self.presentationStyle = presentationStyle
        self.onDismiss = onDismiss
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if presentationStyle == .overlay {
                    headerBar
                }

                commentsScrollView
                if canComment {
                    commentInput
                } else {
                    restrictedInteractionNotice
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .toast($commentsManager.toastMessage)
            .modifier(CommentsPresentationModifier(style: presentationStyle, title: titleText, onDismiss: onDismiss))
            .onAppear {
                pendingFocusCommentId = commentsManager.focusCommentId
                setupKeyboardObservers()
                Task { await loadAnonProfileId() }
                attemptFocusScroll(proxy)
            }
            .onDisappear {
                removeKeyboardObservers()
                cleanupSelectedMedia()
                VideoPlaybackManager.shared.requestVisibilityRefresh()
            }
            .onChange(of: isAnonymousMode) { _, _ in
                Task { await loadAnonProfileId() }
            }
            .onChange(of: commentsManager.editTarget?.backendId) { _, newValue in
                if let newValue, let target = commentsManager.editTarget, target.backendId == newValue {
                    commentText = target.content
                    cleanupSelectedMedia()
                    selectedMedia = []
                } else if commentsManager.editTarget == nil {
                    commentText = ""
                    cleanupSelectedMedia()
                    selectedMedia = []
                }
            }
            .onChange(of: commentsManager.currentComments.count) { _, _ in
                attemptFocusScroll(proxy)
            }
            .onReceive(commentsManager.$replyThreads) { _ in
                attemptFocusScroll(proxy)
            }
            .fullScreenCover(isPresented: $showHashtagFeed, onDismiss: {
                selectedHashtag = nil
            }) {
                if let hashtag = selectedHashtag {
                    HashtagFeedView(hashtag: hashtag, presentationStyle: .overlay)
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
            .fullScreenCover(item: $selectedVideo) { selection in
                VideoPlayerSheet(
                    selection: selection,
                    isPresented: Binding(
                        get: { selectedVideo != nil },
                        set: { if !$0 { selectedVideo = nil } }
                    )
                )
            }
        }
    }
}

private struct CommentsPresentationModifier: ViewModifier {
    let style: CommentsView.PresentationStyle
    let title: String
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        switch style {
        case .overlay:
            content
                .navigationBarHidden(true)
                .edgeSwipeToDismiss { onDismiss() }
        case .navigation:
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct CommentsKeyboardDismissalModifier: ViewModifier {
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded { onDismiss() })
        } else {
            content
                .simultaneousGesture(DragGesture().onChanged { _ in onDismiss() })
                .simultaneousGesture(TapGesture().onEnded { onDismiss() })
        }
    }
}

// MARK: - Subviews
private extension CommentsView {
    var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            LoopedBackButton(action: onDismiss)

            Text(titleText)
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
            Group {
                if post.isAnonymous {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.15))
                        .overlay(
                            Text(String(postAuthorName.prefix(1)).uppercased())
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                        )
                        .frame(width: 40, height: 40)
                } else {
                    ProfileAvatarView(imageURL: post.authorProfileImageURL, size: 40)
                }
            }

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
	                            DispatchQueue.main.async {
	                                showImageViewer = true
	                            }
	                        },
                        onVideoTap: { selection in
                            let trimmed = selection.url.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            let communityLabel = post.communityDisplayName(preferShortNames: true).map { "in \($0)" }
                            selectedVideo = VideoSelection(
                                url: trimmed,
                                thumbnailUrl: selection.thumbnailUrl,
                                authorName: post.resolvedAuthorName,
                                authorImageUrl: post.authorProfileImageURL,
                                communityName: communityLabel,
                                caption: post.content,
                                inlineId: selection.inlineId,
                                inlineViewModel: selection.inlineViewModel
                            )
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
                    .foregroundColor(error == "Content unavailable" ? .loopedTextSecondary : .loopedError)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else if comments.isEmpty {
                VStack(spacing: 10) {
                    Text("No comments yet")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    if canComment {
                        Text("Be the first to share your thoughts.")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                LazyVStack(spacing: 20) {
                    if let error = commentsManager.errorMessage {
                        Text(error)
                            .font(.loopedSmallText)
                            .foregroundColor(error == "Content unavailable" ? .loopedTextSecondary : .loopedError)
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
                            onReply: canComment ? { commentsManager.setReplyTarget($0) } : nil,
                            onToggleReplies: { tapped in
                                Task { await commentsManager.toggleReplies(for: tapped) }
                            },
                            onLoadMoreReplies: { tapped in
                                Task { await commentsManager.loadMoreRepliesIfNeeded(for: tapped) }
                            },
                            onLike: canComment ? { tappedComment in
                                Task { await commentsManager.toggleLike(for: tappedComment) }
                            } : nil,
                            canManage: { canManage(comment: $0) },
                            onEdit: { target in
                                commentsManager.setEditTarget(target)
                            },
                            onDelete: { target in
                                Task { await commentsManager.deleteComment(target) }
                            },
                            onHashtagTap: handleHashtagTap
                        )
                        .id(comment.backendId ?? comment.id.hashValue)
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
            if !selectedMedia.isEmpty {
                MediaPreviewGrid(
                    media: selectedMedia,
                    maxHeight: 180,
                    onRemove: { item in
                        TemporaryMediaFile.deleteIfOwned(item.videoURL)
                        selectedMedia.removeAll { $0.id == item.id }
                    }
                )
                .padding(.horizontal, 20)
            }

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

            HStack(alignment: .bottom, spacing: 12) {
                ProfileAvatarView(
                    imageURL: authViewModel.currentUser?.profileImageURL,
                    size: 34
                )

                Button(action: { showMediaPicker = true }) {
                    Image(systemName: "paperclip")
                        .font(.loopedCustom(.medium, size: 18))
                        .foregroundColor(.loopedPrimary)
                }
                .disabled(commentsManager.editTarget != nil)

                Button(action: { showCamera = true }) {
                    Image(systemName: "camera")
                        .font(.loopedCustom(.medium, size: 18))
                        .foregroundColor(.loopedPrimary)
                }
                .disabled(commentsManager.editTarget != nil)

                TextField(inputPlaceholder, text: $commentText, axis: .vertical)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1...4)
                    .focused($isCommentFieldFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button(action: {
                    Task {
                        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if commentsManager.editTarget != nil {
                            guard !trimmed.isEmpty else { return }
                            await commentsManager.editComment(content: trimmed)
	                        } else {
	                            guard !trimmed.isEmpty || !selectedMedia.isEmpty else { return }
	                            await commentsManager.postComment(content: trimmed, media: selectedMedia)
	                            cleanupSelectedMedia()
	                            selectedMedia = []
	                        }
	                        commentText = ""
                            dismissKeyboard()
	                    }
	                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.loopedCustom(.semibold, size: 28))
                        .foregroundColor(
                            (commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedMedia.isEmpty)
                            || commentsManager.isPosting
                            ? .loopedTextSecondary
                            : .loopedPrimary
                        )
                }
                .disabled(
                    (commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedMedia.isEmpty)
                    || commentsManager.isPosting
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, max(12, keyboardHeight > 0 ? 8 : 12))
            .background(Color.loopedBackground)
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView(
                selectedMedia: $selectedMedia,
                maxSelectionCount: 1,
                allowsVideo: true,
                appendSelection: false,
                onDismiss: { showMediaPicker = false }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraMediaPickerView(selectedItem: .init(
                get: { nil },
                set: { item in
                    guard let item else { return }
                    cleanupSelectedMedia()
                    switch item.type {
                    case .image, .video:
                        selectedMedia = [item]
                    case .gif:
                        break
                    }
                }
            ))
        }
    }
}

private extension CommentsView {
    func cleanupSelectedMedia() {
        for item in selectedMedia {
            TemporaryMediaFile.deleteIfOwned(item.videoURL)
        }
    }
}

// MARK: - Keyboard helpers
private extension CommentsView {
    func attemptFocusScroll(_ proxy: ScrollViewProxy) {
        guard let focusId = pendingFocusCommentId else { return }
        guard focusCommentExists(focusId) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(focusId, anchor: .top)
        }
        pendingFocusCommentId = nil
    }

    func focusCommentExists(_ focusId: Int) -> Bool {
        if commentsManager.currentComments.contains(where: { $0.backendId == focusId }) {
            return true
        }
        return commentsManager.replyThreads.values.contains { thread in
            thread.replies.contains { $0.backendId == focusId }
        }
    }

	    func setupKeyboardObservers() {
	        guard keyboardWillShowObserver == nil, keyboardWillHideObserver == nil else { return }

	        keyboardWillShowObserver = NotificationCenter.default.addObserver(
	            forName: UIResponder.keyboardWillShowNotification,
	            object: nil,
	            queue: .main
	        ) { notification in
	            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
	                keyboardHeight = keyboardFrame.height
	            }
	        }

	        keyboardWillHideObserver = NotificationCenter.default.addObserver(
	            forName: UIResponder.keyboardWillHideNotification,
	            object: nil,
	            queue: .main
	        ) { _ in
	            keyboardHeight = 0
	        }
	    }

	    func removeKeyboardObservers() {
	        if let keyboardWillShowObserver {
	            NotificationCenter.default.removeObserver(keyboardWillShowObserver)
	            self.keyboardWillShowObserver = nil
	        }
	        if let keyboardWillHideObserver {
	            NotificationCenter.default.removeObserver(keyboardWillHideObserver)
	            self.keyboardWillHideObserver = nil
	        }
	    }

	    func dismissKeyboard() {
	        DispatchQueue.main.async {
	            isCommentFieldFocused = false
	            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
	        }
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

    var restrictedInteractionMessage: String {
        if commentsManager.isLoadingPermissions {
            return "Checking permissions..."
        }
        if joinIsRequired {
            return "Join this major or field to comment or interact."
        }
        return "You can’t comment or interact with comments because you aren’t verified."
    }

    var restrictedInteractionNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.loopedCustom(.semibold, size: 16))
                    .foregroundColor(.loopedSecondary)

                Text(restrictedInteractionMessage)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            if joinIsRequired {
                Button(action: { Task { await joinSpecializationIfNeeded() } }) {
                    Text(isJoiningSpecialization ? "Joining..." : "Join")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedWhite)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.loopedPrimary)
                        .clipShape(Capsule())
                }
                .disabled(isJoiningSpecialization)
                .opacity(isJoiningSpecialization ? 0.7 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.loopedBackground)
    }

    @MainActor
    func joinSpecializationIfNeeded() async {
        guard joinIsRequired else { return }
        guard let specializationId = post.communityId else { return }
        guard !isJoiningSpecialization else { return }
        isJoiningSpecialization = true
        defer { isJoiningSpecialization = false }

        do {
            try await communityService.joinSpecialization(id: specializationId)
            await CommunityPermissionsCache.shared.invalidate(communityId: specializationId)
            await commentsManager.refreshCommunityPermissions()
            await feedViewModel.loadFollowedCommunities(reset: true)
            commentsManager.toastMessage = ToastMessage(text: "Joined", kind: .success)
        } catch {
            if case let APIError.apiError(_, apiError, message) = error {
                let text: String
                switch apiError {
                case "specialization_verification_required":
                    text = message ?? "Verification required to join."
                default:
                    text = message ?? apiError
                }
                commentsManager.toastMessage = ToastMessage(text: text, kind: .error)
            } else {
                commentsManager.toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
            }
        }
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
