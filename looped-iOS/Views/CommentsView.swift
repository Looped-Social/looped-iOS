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
    let onOpenHashtag: ((String) -> Void)?
    let onOpenMention: ((String) -> Void)?
    @EnvironmentObject var commentsManager: CommentsModalManager
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames
    @Environment(\.loopedOpenHashtag) private var openHashtag
    @Environment(\.loopedOpenMention) private var openMention
    @AppStorage("anonymousMode") private var isAnonymousMode = false
    @State private var commentText: String = ""
    @State private var selectedMedia: [LocalMediaItem] = []
    @State private var keyboardHeight: CGFloat = 0
    @State private var selectedImageIndex: Int = 0
    @State private var showImageViewer = false
    @State private var selectedVideo: VideoSelection?
    @State private var anonProfileId: Int?
    @State private var pendingFocusCommentId: Int?
    @State private var showMediaPicker = false
	@State private var showCamera = false
	@State private var showAttachmentOptions = false
	@State private var keyboardWillShowObserver: NSObjectProtocol?
	@State private var keyboardWillHideObserver: NSObjectProtocol?
    @State private var activeModerationSheet: ModerationSheet?
    @State private var selectedCommentForModeration: Comment?
    @State private var moderationAlertMessage: String?
    @State private var isPostLikeLoading = false
    @State private var isPostRepostLoading = false
    @State private var postLikeCountOverride: Int?
    @State private var postIsLikedOverride: Bool?
    @State private var postViewerHasRepostedOverride: Bool?
    @State private var isPreparingPostShareSheet = false
    @State private var showPostShareSheet = false
    @State private var postShareItems: [Any] = []
    @State private var postShareCountOverride: Int?
    @State private var isPostShareTracking = false
	@FocusState private var isCommentFieldFocused: Bool

    private let moderationService: ModerationServiceProtocol = ModerationService()
    private let feedService: FeedServiceProtocol = FeedService()

	private var comments: [Comment] {
		commentsManager.currentComments
	}

    private var canComment: Bool {
        if isAnonymousMode {
            return true
        }
        if let capabilities = post.viewerCapabilities {
            return capabilities.canInteract && capabilities.canComment
        }
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

    private var canReply: Bool {
        if isAnonymousMode {
            return true
        }
        if let capabilities = post.viewerCapabilities {
            return capabilities.canInteract && capabilities.canReply
        }
        return canComment
    }

    private var canLikeComments: Bool {
        if isAnonymousMode {
            return true
        }
        if let capabilities = post.viewerCapabilities {
            return capabilities.canInteract && capabilities.canLike
        }
        return canComment
    }

    private var joinIsRequired: Bool {
        if post.viewerCapabilities?.lockReason == .specializationNotJoined {
            return true
        }
        guard let permissions = commentsManager.communityPermissions else { return false }
        return permissions.requiresJoin && !permissions.canPost
    }

    private var postAuthorName: String {
        post.resolvedAuthorName
    }

    private var postAuthorDisplayLine: String? {
        post.authorDisplaySpecializationLine(preferShortNames: preferCommunityShortNames)
    }

    private var postCommunityContextText: String? {
        if let name = post.communityDisplayName(preferShortNames: preferCommunityShortNames) {
            return "Posted in \(name)"
        }
        if let kind = post.communityKind, kind != .unknown {
            return "Posted in \(kind.rawValue.capitalized)"
        }
        return nil
    }

    private var postAuthorProfileId: Int? {
        if post.isAnonymous {
            return post.anonProfileId
        }
        return post.authorBackendId ?? post.authorId.backendInt
    }

    private var imageUrls: [String] {
        post.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    private var titleText: String {
        let count = displayedThreadCommentCount
        return "\(count) comment\(count == 1 ? "" : "s")"
    }

    private var displayedThreadCommentCount: Int {
        let backendTotal = commentsManager.currentPost?.commentsCount ?? post.commentsCount
        let loadedTopLevel = comments.count
        let loadedReplies = comments.reduce(0) { partial, comment in
            partial + max(comment.totalReplyCount ?? comment.replyCount, 0)
        }
        let loadedThreadTotal = loadedTopLevel + loadedReplies
        if backendTotal > 0 {
            return max(backendTotal, loadedThreadTotal)
        }
        return loadedThreadTotal
    }

    private var displayedPostLikeCount: Int {
        max(postLikeCountOverride ?? post.reactionCount, 0)
    }

    private var displayedPostShareCount: Int {
        max(postShareCountOverride ?? post.shareCount, 0)
    }

    private var isPostLiked: Bool {
        postIsLikedOverride ?? (post.userReaction == .like)
    }

    private var isPostReposted: Bool {
        postViewerHasRepostedOverride ?? post.viewerHasReposted
    }

    private var canLikePost: Bool {
        if isAnonymousMode {
            return true
        }
        if let capabilities = post.viewerCapabilities {
            return capabilities.canInteract && capabilities.canLike
        }
        return canComment
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
        onOpenHashtag: ((String) -> Void)? = nil,
        onOpenMention: ((String) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.post = post
        self.presentationStyle = presentationStyle
        self.onOpenHashtag = onOpenHashtag
        self.onOpenMention = onOpenMention
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
                } else if !canReply && !canLikeComments {
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
                Task { await commentsManager.refreshCommunityPermissions() }
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
            .sheet(isPresented: $showPostShareSheet) {
                ShareSheet(items: postShareItems.isEmpty ? defaultPostShareItems : postShareItems) { completed, activityType in
                    if shouldTrackPostShare(completed: completed, activityType: activityType) {
                        trackPostShare()
                    }
                }
            }
            .sheet(item: $activeModerationSheet, onDismiss: {
                selectedCommentForModeration = nil
            }) { sheet in
                moderationSheetContent(sheet)
            }
            .alert("Report Submitted", isPresented: moderationAlertIsPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(moderationAlertMessage ?? "")
            }
            .toolbar {
                if presentationStyle == .navigation && canReportPost {
                    ToolbarItem(placement: .topBarTrailing) {
                        postOptionsButton
                    }
                }
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
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(.loopedCommentsScreenTitle)
                            .foregroundColor(.loopedTextPrimary)
                    }
                }
        }
    }
}

private struct CommentsKeyboardDismissalModifier: ViewModifier {
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded { onDismiss() },
                    including: .gesture
                )
        } else {
            content
                .simultaneousGesture(
                    DragGesture().onChanged { _ in onDismiss() },
                    including: .gesture
                )
                .simultaneousGesture(
                    TapGesture().onEnded { onDismiss() },
                    including: .gesture
                )
        }
    }
}

// MARK: - Subviews
private extension CommentsView {
    var headerBar: some View {
        ZStack {
            Text(titleText)
                .font(.loopedCommentsScreenTitle)
                .foregroundColor(.loopedTextPrimary)

            HStack {
                LoopedBackButton(action: onDismiss)
                Spacer()
                if canReportPost {
                    postOptionsButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.loopedBackground)
    }

    var postOptionsButton: some View {
        Menu {
            if canReportPost {
                Button("Report Post", role: .destructive) {
                    activeModerationSheet = .reportPost
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.loopedCustom(.medium, size: 18))
                .foregroundColor(.loopedTextSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Post options")
    }

    var threadHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            threadAuthorAvatar

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(postAuthorName)
                        .font(.loopedCommentsPostAuthor)
                        .foregroundColor(.loopedTextStrong)
                        .fixedSize(horizontal: false, vertical: true)

                    if postAuthorDisplayLine != nil || postCommunityContextText != nil {
                        HStack(spacing: 4) {
                            if let postAuthorDisplayLine {
                                Text(postAuthorDisplayLine)
                                    .font(.loopedCommentsPostMeta)
                                    .foregroundColor(.loopedTextSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            if postAuthorDisplayLine != nil, postCommunityContextText != nil {
                                Text("•")
                                    .font(.loopedCommentsPostMeta)
                                    .foregroundColor(.loopedTextSecondary)
                            }

                            if let postCommunityContextText {
                                Text(postCommunityContextText)
                                    .font(.loopedSubBodyRegular)
                                    .foregroundColor(.loopedTextSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }

                let trimmedContent = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedContent.isEmpty {
                    HashtagText(
                        text: trimmedContent,
                        font: .loopedCommentsPostBody,
                        textColor: .loopedTextPrimary,
                        hashtagColor: .loopedPrimary,
                        onHashtagTap: handleHashtagTap,
                        onMentionTap: handleMentionTap
                    )
                    .multilineTextAlignment(.leading)
                }

                Text(formattedTimestamp(for: post.createdAt))
                    .font(.loopedCommentsPostMeta)
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
                            let communityLabel = post.communityDisplayName(preferShortNames: true).map { "Posted in \($0)" }
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

                    threadEngagementBar
	            }
	        }
	    }

    private var threadEngagementBar: some View {
        HStack(spacing: 14) {
            Button(action: togglePostLike) {
                HStack(spacing: 4) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: isPostLiked ? "heart.fill" : "heart")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(isPostLiked ? .loopedError : .loopedTextSecondary)

                        if !canLikePost {
                            Image(systemName: "lock.fill")
                                .font(.loopedSymbol(.bold, size: 10))
                                .foregroundColor(.loopedTextSecondary)
                                .padding(3)
                                .background(Circle().fill(Color.loopedBackground))
                                .offset(x: 8, y: -8)
                        }
                    }
                    Text("\(displayedPostLikeCount)")
                        .font(.loopedCommentsPostMeta)
                        .foregroundColor(.loopedTextSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isPostLikeLoading)
            .opacity(isPostLikeLoading ? 0.6 : 1.0)

            Button(action: togglePostRepost) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundColor(isPostReposted ? .loopedPrimary : .loopedTextSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isPostRepostLoading)
            .opacity(isPostRepostLoading ? 0.6 : 1.0)

            Button(action: preparePostShareSheet) {
                HStack(spacing: 4) {
                    Image("send-icon-fab")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.loopedTextSecondary)
                    Text("\(displayedPostShareCount)")
                        .font(.loopedCommentsPostMeta)
                        .foregroundColor(.loopedTextSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isPreparingPostShareSheet)
            .opacity(isPreparingPostShareSheet ? 0.6 : 1.0)

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private var threadAuthorAvatar: some View {
        if let postAuthorProfileId {
            NavigationLink(destination: postAuthorProfileDestination(profileId: postAuthorProfileId)) {
                ProfileAvatarView(
                    imageURL: post.authorProfileImageURL,
                    size: 44,
                    variant: post.isAnonymous ? .anonymous : .standard
                )
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            ProfileAvatarView(
                imageURL: post.authorProfileImageURL,
                size: 44,
                variant: post.isAnonymous ? .anonymous : .standard
            )
        }
    }

    @ViewBuilder
    private func postAuthorProfileDestination(profileId: Int) -> some View {
        if post.isAnonymous {
            UserProfileView(anonProfileId: profileId)
        } else {
            UserProfileView(userId: profileId)
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
                LazyVStack(spacing: 0) {
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
                            isLikeLocked: !canLikeComments,
                            onReply: canReply ? { commentsManager.setReplyTarget($0) } : nil,
                            onToggleReplies: { tapped in
                                Task { await commentsManager.toggleReplies(for: tapped) }
                            },
                            onLoadMoreReplies: { tapped in
                                Task { await commentsManager.loadMoreRepliesIfNeeded(for: tapped) }
                            },
                            onLike: canLikeComments ? { tappedComment in
                                Task { await commentsManager.toggleLike(for: tappedComment) }
                            } : nil,
                            canManage: { canManage(comment: $0) },
                            onEdit: { target in
                                commentsManager.setEditTarget(target)
                            },
                            onDelete: { target in
                                Task { await commentsManager.deleteComment(target) }
                            },
                            canReport: { canReport(comment: $0) },
                            onReport: { target in
                                selectedCommentForModeration = target
                                activeModerationSheet = .reportComment
                            },
                            onHashtagTap: handleHashtagTap,
                            onMentionTap: handleMentionTap,
                            threadStateProvider: { commentsManager.threadState(for: $0) }
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
                .padding(.horizontal, 16)
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
                            .loopedTapTarget()
                    }
                }
                .padding(.horizontal, 4)
            }

            if commentsManager.editTarget != nil {
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
                            .loopedTapTarget()
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ProfileAvatarView(
                    imageURL: isAnonymousMode ? nil : authViewModel.currentUser?.profileImageURL,
                    size: 34,
                    variant: isAnonymousMode ? .anonymous : .standard
                )

                Button(action: { showAttachmentOptions.toggle() }) {
                    Image(systemName: "plus")
                        .font(.loopedCustom(.medium, size: 18))
                        .foregroundColor(.loopedPrimary)
                        .loopedTapTarget()
                }
                .disabled(commentsManager.editTarget != nil || !selectedMedia.isEmpty)

                HStack(spacing: 6) {
                    TextField(inputPlaceholder, text: $commentText, axis: .vertical)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1...4)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isCommentFieldFocused)

                    if shouldShowSendButton {
                        Button(action: sendComment) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.loopedCustom(size: 24))
                                .foregroundColor(.loopedPrimary)
                                .loopedTapTarget()
                        }
                        .disabled(isSendDisabled)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.loopedMessageMutedColor)
                        .shadow(color: .loopedBlack.opacity(0.10), radius: 1, x: 0, y: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, max(12, keyboardHeight > 0 ? 8 : 12))
            .background(Color.loopedBackground)
        }
        .actionSheet(isPresented: $showAttachmentOptions) {
            ActionSheet(
                title: Text("Add Attachment"),
                message: Text("Choose an option"),
                buttons: [
                    .default(Text("Photo Library")) {
                        showMediaPicker = true
                    },
                    .default(Text("Camera")) {
                        showCamera = true
                    },
                    .cancel()
                ]
            )
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
    var shouldShowSendButton: Bool {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if commentsManager.editTarget != nil {
            return !trimmed.isEmpty
        }
        return !trimmed.isEmpty || !selectedMedia.isEmpty
    }

    var isSendDisabled: Bool {
        commentsManager.isPosting
    }

    func sendComment() {
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
    }

    var canonicalPostURL: URL? {
        guard let postId = post.backendId else { return nil }
        return URL(string: "https://mylooped.app/p/\(postId)")
    }

    var defaultPostShareItems: [Any] {
        if let canonicalPostURL {
            return [canonicalPostURL]
        }
        return ["Check this out on Looped"]
    }

    func togglePostLike() {
        guard !isPostLikeLoading else { return }
        guard canLikePost else {
            commentsManager.toastMessage = ToastMessage(text: restrictedInteractionMessage, kind: .info)
            return
        }
        guard let postId = post.backendId else {
            commentsManager.toastMessage = ToastMessage(text: "Post data is missing. Pull to refresh and try again.", kind: .error)
            return
        }
        isPostLikeLoading = true
        let shouldLike = !isPostLiked

        Task {
            defer { isPostLikeLoading = false }
            do {
                let response: PostReactionResponse
                if shouldLike {
                    response = try await feedService.reactToPost(
                        postId: postId,
                        communityId: post.communityId,
                        reaction: .like
                    )
                } else {
                    response = try await feedService.unlikePost(
                        postId: postId,
                        communityId: post.communityId
                    )
                }
                postIsLikedOverride = shouldLike
                postLikeCountOverride = response.likesCount
                let updated = post.updating(
                    reactionCount: response.likesCount,
                    userReaction: .some(shouldLike ? .like : nil),
                    updatedAt: Date()
                )
                if let existing = feedViewModel.posts.first(where: { $0.backendId == postId }) {
                    let merged = existing.updating(
                        reactionCount: response.likesCount,
                        userReaction: .some(shouldLike ? .like : nil),
                        updatedAt: Date()
                    )
                    feedViewModel.updatePost(merged)
                } else {
                    feedViewModel.updatePost(updated)
                }
                if let current = commentsManager.currentPost, current.backendId == postId {
                    commentsManager.currentPost = current.updating(
                        reactionCount: response.likesCount,
                        userReaction: .some(shouldLike ? .like : nil),
                        updatedAt: Date()
                    )
                }
            } catch {
                if isNotFound(error) {
                    commentsManager.toastMessage = ToastMessage(text: "Content unavailable", kind: .info)
                    return
                }
                commentsManager.toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
            }
        }
    }

    func togglePostRepost() {
        guard !isPostRepostLoading else { return }
        guard let postId = post.backendId else {
            commentsManager.toastMessage = ToastMessage(text: "Post data is missing. Pull to refresh and try again.", kind: .error)
            return
        }
        isPostRepostLoading = true
        let previousValue = isPostReposted

        Task {
            defer { isPostRepostLoading = false }
            do {
                let response: PostRepostResponse
                if previousValue {
                    response = try await feedService.unrepostPost(postId: postId)
                } else {
                    response = try await feedService.repostPost(postId: postId)
                }
                postViewerHasRepostedOverride = response.viewerHasReposted
                let updated = post.updating(
                    viewerHasReposted: response.viewerHasReposted,
                    updatedAt: Date()
                )
                if let existing = feedViewModel.posts.first(where: { $0.backendId == postId }) {
                    let merged = existing.updating(
                        viewerHasReposted: response.viewerHasReposted,
                        updatedAt: Date()
                    )
                    feedViewModel.updatePost(merged)
                } else {
                    feedViewModel.updatePost(updated)
                }
                if let current = commentsManager.currentPost, current.backendId == postId {
                    commentsManager.currentPost = current.updating(
                        viewerHasReposted: response.viewerHasReposted,
                        updatedAt: Date()
                    )
                }
            } catch {
                if isNotFound(error) {
                    commentsManager.toastMessage = ToastMessage(text: "Content unavailable", kind: .info)
                    return
                }
                commentsManager.toastMessage = ToastMessage(text: repostErrorMessage(for: error), kind: .error)
            }
        }
    }

    func preparePostShareSheet() {
        guard !isPreparingPostShareSheet else { return }
        isPreparingPostShareSheet = true
        Task { @MainActor in
            defer { isPreparingPostShareSheet = false }
            postShareItems = defaultPostShareItems
            showPostShareSheet = true
        }
    }

    func shouldTrackPostShare(completed: Bool, activityType: UIActivity.ActivityType?) -> Bool {
        guard completed else { return false }
        if activityType == .copyToPasteboard {
            return false
        }
        return post.backendId != nil
    }

    func trackPostShare() {
        guard let postId = post.backendId, !isPostShareTracking else { return }
        isPostShareTracking = true
        Task {
            defer { isPostShareTracking = false }
            do {
                let response = try await feedService.sharePost(postId: postId)
                postShareCountOverride = response.shareCount
                let updated = post.updating(shareCount: response.shareCount, updatedAt: Date())
                if let existing = feedViewModel.posts.first(where: { $0.backendId == postId }) {
                    let merged = existing.updating(shareCount: response.shareCount, updatedAt: Date())
                    feedViewModel.updatePost(merged)
                } else {
                    feedViewModel.updatePost(updated)
                }
                if let current = commentsManager.currentPost, current.backendId == postId {
                    commentsManager.currentPost = current.updating(shareCount: response.shareCount, updatedAt: Date())
                }
            } catch {
                if isNotFound(error) {
                    commentsManager.toastMessage = ToastMessage(text: "Content unavailable", kind: .info)
                    return
                }
                commentsManager.toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
            }
        }
    }

    func cleanupSelectedMedia() {
        for item in selectedMedia {
            TemporaryMediaFile.deleteIfOwned(item.videoURL)
        }
    }

    func repostErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .apiError(_, let error, let message):
                if error == "community_banned" {
                    return "You can’t repost in this community."
                }
                if error == "forbidden" {
                    return "You can’t repost this post."
                }
                if error == "user_not_provisioned" {
                    return "Finish setting up your account to repost."
                }
                if error == "self_repost_not_allowed" {
                    return "You cannot repost your own post."
                }
                return message ?? "This action isn't available right now."
            case .unauthorized:
                return "Please sign in again and try reposting."
            default:
                return "This action isn't available right now."
            }
        }
        return error.localizedDescription
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
        comment.resolvedAuthorName
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

    func canReport(comment: Comment) -> Bool {
        guard !comment.isDeleted else { return false }
        guard comment.backendId != nil else { return false }
        if canManage(comment: comment) {
            return false
        }
        return true
    }

    var canReportPost: Bool {
        post.backendId != nil
    }

    @ViewBuilder
    func moderationSheetContent(_ sheet: ModerationSheet) -> some View {
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
        case .reportComment:
            ReportReasonSheet(
                title: "Report Comment",
                onSubmit: { reason in
                    guard let backendId = selectedCommentForModeration?.backendId else {
                        throw ModerationError.missingTarget
                    }
                    _ = try await moderationService.createReport(
                        targetType: "comment",
                        targetId: backendId,
                        reason: reason
                    )
                },
                onSuccess: { moderationAlertMessage = "Thanks for reporting. We'll review it shortly." }
            )
        }
    }

    var moderationAlertIsPresented: Binding<Bool> {
        Binding(
            get: { moderationAlertMessage != nil },
            set: { if !$0 { moderationAlertMessage = nil } }
        )
    }

    var inputPlaceholder: String {
        commentsManager.editTarget == nil ? "Add a comment..." : "Edit comment..."
    }

    var restrictedInteractionMessage: String {
        if let capabilities = post.viewerCapabilities {
            if capabilities.lockReason == .specializationNotJoined {
                return "Join \(commentLockSpecializationName) to comment."
            }
            if capabilities.lockReason == .communityNotVerified || capabilities.lockReason == .verificationExpired {
                return "Verify in \(commentLockCommunityName) to comment."
            }
            return capabilities.lockMessage(for: "comment")
        }
        if commentsManager.isLoadingPermissions {
            return "Checking permissions..."
        }
        if joinIsRequired {
            return "Join \(commentLockSpecializationName) to comment."
        }
        return "Verify in \(commentLockCommunityName) to comment."
    }

    var commentLockCommunityName: String {
        if let name = post.communityDisplayName(preferShortNames: preferCommunityShortNames)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let name = post.communityName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return "this community"
    }

    var commentLockSpecializationName: String {
        if let name = post.viewerCapabilities?.lockContext?.specializationName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let name = post.communityDisplayName(preferShortNames: preferCommunityShortNames)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        return "this major or field"
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
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.loopedBackground)
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
        if let onOpenHashtag {
            onOpenHashtag(cleanHashtag)
            return
        }
        openHashtag(cleanHashtag)
    }

    func handleMentionTap(_ mention: String) {
        let trimmed = mention.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHandle = (trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed).lowercased()
        guard !cleanHandle.isEmpty else { return }
        if let onOpenMention {
            onOpenMention(cleanHandle)
            return
        }
        openMention(cleanHandle)
    }

    func isNotFound(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let code):
                return code == 404
            case .apiError(let code, _, _):
                return code == 404
            default:
                return false
            }
        }
        return false
    }
}

private extension CommentsView {
    enum ModerationSheet: String, Identifiable {
        case reportPost
        case reportComment

        var id: String { rawValue }
    }

    enum ModerationError: LocalizedError {
        case missingTarget

        var errorDescription: String? {
            "This action isn't available right now."
        }
    }
}

#if DEBUG
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

	    let manager: CommentsModalManager = {
	        let manager = CommentsModalManager()
	        manager.currentPost = samplePost
	        manager.currentComments = MockComments.getCommentsForPost(samplePost.id)
	        return manager
	    }()

    CommentsView(post: samplePost) {}
        .environmentObject(manager)
        .environmentObject(FeedViewModel())
        .environmentObject(AuthViewModel())
}
#endif
