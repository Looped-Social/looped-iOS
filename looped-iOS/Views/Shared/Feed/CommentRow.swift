import SwiftUI
import Foundation

struct CommentRow: View {
    let comment: Comment
    let nestingLevel: Int
    let replies: [Comment]
    let isExpanded: Bool
    let isLoadingReplies: Bool
    let isLoadingMoreReplies: Bool
    let hasMoreReplies: Bool
    let isLikeLocked: Bool
    let onReply: ((Comment) -> Void)?
    let onToggleReplies: ((Comment) -> Void)?
    let onLoadMoreReplies: ((Comment) -> Void)?
    let onLike: ((Comment) -> Void)?
    let canManage: ((Comment) -> Bool)?
    let onEdit: ((Comment) -> Void)?
    let onDelete: ((Comment) -> Void)?
    let canReport: ((Comment) -> Bool)?
    let onReport: ((Comment) -> Void)?
    let onHashtagTap: ((String) -> Void)?
    let onMentionTap: ((String) -> Void)?
    let threadStateProvider: ((Comment) -> ReplyThreadState)?

    @State private var selectedImageIndex: Int = 0
    @State private var showImageViewer = false
    @State private var selectedVideo: VideoSelection?
    @State private var showActionMenu = false

    init(
        comment: Comment,
        nestingLevel: Int = 0,
        replies: [Comment] = [],
        isExpanded: Bool = false,
        isLoadingReplies: Bool = false,
        isLoadingMoreReplies: Bool = false,
        hasMoreReplies: Bool = false,
        isLikeLocked: Bool = false,
        onReply: ((Comment) -> Void)? = nil,
        onToggleReplies: ((Comment) -> Void)? = nil,
        onLoadMoreReplies: ((Comment) -> Void)? = nil,
        onLike: ((Comment) -> Void)? = nil,
        canManage: ((Comment) -> Bool)? = nil,
        onEdit: ((Comment) -> Void)? = nil,
        onDelete: ((Comment) -> Void)? = nil,
        canReport: ((Comment) -> Bool)? = nil,
        onReport: ((Comment) -> Void)? = nil,
        onHashtagTap: ((String) -> Void)? = nil,
        onMentionTap: ((String) -> Void)? = nil,
        threadStateProvider: ((Comment) -> ReplyThreadState)? = nil
    ) {
        self.comment = comment
        self.nestingLevel = nestingLevel
        self.replies = replies
        self.isExpanded = isExpanded
        self.isLoadingReplies = isLoadingReplies
        self.isLoadingMoreReplies = isLoadingMoreReplies
        self.hasMoreReplies = hasMoreReplies
        self.isLikeLocked = isLikeLocked
        self.onReply = onReply
        self.onToggleReplies = onToggleReplies
        self.onLoadMoreReplies = onLoadMoreReplies
        self.onLike = onLike
        self.canManage = canManage
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.canReport = canReport
        self.onReport = onReport
        self.onHashtagTap = onHashtagTap
        self.onMentionTap = onMentionTap
        self.threadStateProvider = threadStateProvider
    }
    
    private var displayName: String {
        comment.resolvedAuthorName
    }

    private var formattedTimestamp: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(comment.createdAt)

        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60

        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
    
    private var profileSize: CGFloat {
        nestingLevel == 0 ? 40 : 32
    }

    private var contentFont: Font {
        nestingLevel == 0 ? .loopedCommentsBody : .loopedCommentsReplyBody
    }

    private var authorFont: Font {
        nestingLevel == 0 ? .loopedCommentsAuthor : .loopedCommentsReplyAuthor
    }

    private var metadataFont: Font {
        nestingLevel == 0 ? .loopedCommentsMeta : .loopedCommentsReplyMeta
    }

    private var actionFont: Font {
        nestingLevel == 0 ? .loopedCommentsAction : .loopedCommentsReplyAction
    }

    private var likesFont: Font {
        nestingLevel == 0 ? .loopedCommentsMetaStrong : .loopedCommentsReplyMetaStrong
    }

    private var likeIconSize: CGFloat {
        nestingLevel == 0 ? 20 : 16
    }

    private var repliesContainerLeadingInset: CGFloat {
        nestingLevel == 0 ? profileSize + 12 : 0
    }

    private var threadConnectorColor: Color {
        Color.loopedTextSecondary.opacity(0.22)
    }

    private var branchConnectorYOffset: CGFloat {
        // Align elbow to avatar midline so the stem feels continuous.
        max(0, (profileSize * 0.5) - 6)
    }

    private var resolvedThreadState: ReplyThreadState {
        if let threadStateProvider {
            return threadStateProvider(comment)
        }
        return ReplyThreadState(
            replies: replies,
            nextCursor: hasMoreReplies ? "has_more" : nil,
            isLoading: isLoadingReplies,
            isLoadingMore: isLoadingMoreReplies,
            isExpanded: isExpanded
        )
    }

    private var likesLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let countText = formatter.string(from: NSNumber(value: comment.likeCount)) ?? "\(comment.likeCount)"
        return "\(countText) like\(comment.likeCount == 1 ? "" : "s")"
    }

    private var backendDirectReplyCount: Int {
        max(comment.replyCount, 0)
    }

    private var backendReplyCount: Int {
        max(comment.totalReplyCount ?? comment.replyCount, 0)
    }

    private var totalKnownReplyCount: Int {
        if backendReplyCount > 0 {
            return backendReplyCount
        }
        return max(resolvedThreadState.replies.count, 0)
    }

    private var avatarView: some View {
        ProfileAvatarView(
            imageURL: comment.authorProfileImageURL,
            size: profileSize,
            variant: comment.isAnonymous ? .anonymous : .standard
        )
    }

    private var authorProfileId: Int? {
        comment.authorBackendId ?? comment.authorId.backendInt
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let authorProfileId {
            NavigationLink(destination: authorProfileDestination(profileId: authorProfileId)) {
                avatarView
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            avatarView
        }
    }

    @ViewBuilder
    private var authorName: some View {
        if let authorProfileId {
            NavigationLink(destination: authorProfileDestination(profileId: authorProfileId)) {
                Text(displayName)
                    .font(authorFont)
                    .foregroundColor(.loopedTextSecondary)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            Text(displayName)
                .font(authorFont)
                .foregroundColor(.loopedTextSecondary)
        }
    }

    @ViewBuilder
    private func authorProfileDestination(profileId: Int) -> some View {
        if comment.isAnonymous {
            UserProfileView(anonProfileId: profileId)
        } else {
            UserProfileView(userId: profileId)
        }
    }

    private var viewRepliesLabel: String? {
        guard totalKnownReplyCount > 0 else { return nil }
        return "View replies (\(totalKnownReplyCount))"
    }

    private var remainingRepliesLabel: String {
        let remaining = max(backendDirectReplyCount - resolvedThreadState.replies.count, 0)
        if remaining > 0 {
            return "View replies (\(remaining))"
        }
        return "View more replies"
    }

    private var imageUrls: [String] {
        comment.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    private func handleDoubleTapLike() {
        guard !comment.isDeleted else { return }
        guard !isLikeLocked else { return }
        guard let onLike else { return }
        guard !comment.userLiked else { return }
        onLike(comment)
    }

    private var canTapLike: Bool {
        onLike != nil && !isLikeLocked
    }

    private var likeIcon: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: comment.userLiked ? "heart.fill" : "heart")
                .font(.loopedSymbol(.regular, size: likeIconSize))
                .foregroundColor(comment.userLiked ? .loopedError : .loopedTextSecondary)

            if isLikeLocked {
                Image(systemName: "lock.fill")
                    .font(.loopedSymbol(.bold, size: 8))
                    .foregroundColor(.loopedTextSecondary)
                    .padding(2)
                    .background(Circle().fill(Color.loopedBackground))
                    .offset(x: likeIconSize >= 20 ? 6 : 5, y: likeIconSize >= 20 ? -6 : -5)
            }
        }
    }

    private var canShowManageActions: Bool {
        guard !comment.isDeleted else { return false }
        guard let canManage, canManage(comment) else { return false }
        return onEdit != nil || onDelete != nil
    }

    private var canShowReportAction: Bool {
        guard !comment.isDeleted else { return false }
        guard let canReport, canReport(comment) else { return false }
        return onReport != nil
    }

    private var canShowActionButton: Bool {
        canShowManageActions || canShowReportAction
    }

    private var likedByCreatorBadge: some View {
        Text("Liked by creator")
            .font(actionFont)
            .foregroundColor(.loopedTextSecondary)
    }

    @ViewBuilder
    private var likeControl: some View {
        let likeStack = HStack(spacing: 0) {
            likeIcon
        }
        .frame(width: 20, height: 20)

        if canTapLike, let onLike {
            Button(action: { onLike(comment) }) {
                likeStack
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            likeStack
        }
    }

    @ViewBuilder
    private var expandedRepliesView: some View {
        let shouldInsetThread = true

        VStack(alignment: .leading, spacing: 10) {
            ForEach(resolvedThreadState.replies) { reply in
                CommentRow(
                    comment: reply,
                    nestingLevel: min(nestingLevel + 1, 1),
                    replies: [],
                    isExpanded: false,
                    isLoadingReplies: false,
                    isLoadingMoreReplies: resolvedThreadState.isLoadingMore,
                    hasMoreReplies: resolvedThreadState.nextCursor != nil,
                    isLikeLocked: isLikeLocked,
                    onReply: onReply,
                    onToggleReplies: onToggleReplies,
                    onLoadMoreReplies: onLoadMoreReplies,
                    onLike: onLike,
                    canManage: canManage,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    canReport: canReport,
                    onReport: onReport,
                    onHashtagTap: onHashtagTap,
                    onMentionTap: onMentionTap,
                    threadStateProvider: threadStateProvider
                )
                .id(reply.backendId ?? reply.id.hashValue)
            }

            if resolvedThreadState.isLoadingMore {
                ProgressView()
                    .padding(.vertical, 4)
            } else if resolvedThreadState.nextCursor != nil {
                Button(action: { onLoadMoreReplies?(comment) }) {
                    Text(remainingRepliesLabel)
                        .font(actionFont)
                        .foregroundColor(.loopedTextSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)
            }
        }
        .padding(.leading, shouldInsetThread ? 16 : 0)
        .padding(.top, 2)
        .overlay(alignment: .leading) {
            if shouldInsetThread {
                Capsule(style: .continuous)
                    .fill(threadConnectorColor)
                    .frame(width: 1.25)
            }
        }
    }

    @ViewBuilder
    private var repliesToggleRow: some View {
        if let onToggleReplies, let viewRepliesLabel {
            Button(action: { onToggleReplies(comment) }) {
                HStack(alignment: .center, spacing: 8) {
                    Text(resolvedThreadState.isExpanded ? "Hide replies" : viewRepliesLabel)
                        .font(actionFont)
                        .foregroundColor(.loopedTextSecondary)

                    if resolvedThreadState.isLoading && !resolvedThreadState.isExpanded {
                        ProgressView()
                            .scaleEffect(0.65)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 6)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                if comment.isDeleted {
                    Color.loopedClear
                        .frame(width: profileSize, height: profileSize)
                } else {
                    authorAvatar
                }

                VStack(alignment: .leading, spacing: 4) {
                    if comment.isDeleted {
                        Text("Comment deleted")
                            .font(contentFont)
                            .foregroundColor(.loopedTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HashtagText(
                            text: comment.content,
                            prefix: "\(displayName) ",
                            prefixFont: authorFont,
                            prefixColor: .loopedTextStrong,
                            font: contentFont,
                            textColor: .loopedTextPrimary,
                            hashtagColor: .loopedPrimary
                        ) { hashtag in
                            onHashtagTap?(hashtag)
                        } onMentionTap: { handle in
                            onMentionTap?(handle)
                        }
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    }

                    if let attachments = comment.attachments, !attachments.isEmpty, !comment.isDeleted {
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
                                selectedVideo = VideoSelection(
                                    url: trimmed,
                                    thumbnailUrl: selection.thumbnailUrl,
                                    authorName: displayName,
                                    authorImageUrl: comment.authorProfileImageURL,
                                    communityName: nil,
                                    caption: comment.content,
                                    inlineId: selection.inlineId,
                                    inlineViewModel: selection.inlineViewModel
                                )
                            }
                        )
                    }

                    if !comment.isDeleted {
                        HStack(alignment: .center, spacing: 10) {
                            Text(formattedTimestamp)
                                .font(metadataFont)
                                .foregroundColor(.loopedTextSecondary)

                            Text(likesLabel)
                                .font(likesFont)
                                .foregroundColor(.loopedTextSecondary)

                            if comment.isUnderReview {
                                Text("Under review")
                                    .font(metadataFont)
                                    .foregroundColor(.loopedTextSecondary)
                            }

                            if let onReply {
                                Button(action: { onReply(comment) }) {
                                    Text("Reply")
                                        .font(actionFont)
                                        .foregroundColor(.loopedTextSecondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        if comment.isLikedByCreator {
                            likedByCreatorBadge
                        }

                        repliesToggleRow
                    }

                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !comment.isDeleted {
                    HStack(alignment: .center, spacing: 4) {
                        likeControl

                        if canShowActionButton {
                            Button(action: { showActionMenu = true }) {
                                Image(systemName: "ellipsis")
                                    .font(.loopedSymbol(.regular, size: 16))
                                    .foregroundColor(.loopedTextSecondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, nestingLevel == 0 ? 2 : 1)
                    .frame(width: canShowActionButton ? 44 : 20, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .loopedDoubleTapToLike {
                handleDoubleTapLike()
            }
            .overlay(alignment: .topLeading) {
                if nestingLevel > 0 {
                    ThreadBranchElbow()
                        .stroke(
                            threadConnectorColor,
                            style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 14, height: 12)
                        .offset(x: -16, y: branchConnectorYOffset)
                }
            }
            .padding(.vertical, nestingLevel == 0 ? 14 : 10)

            if resolvedThreadState.isExpanded {
                expandedRepliesView
                    .padding(.leading, repliesContainerLeadingInset)
                    .padding(.top, 6)
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if !imageUrls.isEmpty {
                FullScreenImageViewer(
                    imageUrls: imageUrls,
                    initialIndex: selectedImageIndex,
                    isPresented: $showImageViewer
                )
            }
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
        .confirmationDialog(
            "Comment options",
            isPresented: $showActionMenu,
            titleVisibility: .visible
        ) {
            if canShowManageActions {
                if let onEdit {
                    Button("Edit Comment") { onEdit(comment) }
                }
                if let onDelete {
                    Button("Delete Comment", role: .destructive) { onDelete(comment) }
                }
            }
            if canShowReportAction, let onReport {
                Button("Report Comment", role: .destructive) { onReport(comment) }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

private struct ThreadBranchElbow: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(6, min(rect.width, rect.height) * 0.5)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: rect.height - radius))
        path.addQuadCurve(
            to: CGPoint(x: radius, y: rect.height),
            control: CGPoint(x: 0, y: rect.height)
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        return path
    }
}

#Preview {
    let sampleComment = Comment(
        postId: UUID(),
        content: "Thank you for these! This is exactly what I needed to improve my workflow.",
        authorId: UUID(),
        authorDisplayName: "Sarah Chen",
        company: "Looped",
        isAnonymous: false,
        likeCount: 78,
        userLiked: false,
        isLikedByCreator: true,
        createdAt: Date().addingTimeInterval(-3600)
    )
    
    VStack {
        CommentRow(comment: sampleComment)
        
        Divider()
            .padding(.horizontal, 16)
        
        CommentRow(comment: Comment(
            postId: UUID(),
            content: "damn i didnt even realize i alr did all this except for the cleaning one i just always think oh lemme clean",
            authorId: UUID(),
            authorDisplayName: "Mike Rodriguez",
            company: "Looped",
            likeCount: 46,
            isLikedByCreator: true,
            createdAt: Date().addingTimeInterval(-7200)
        ))
    }
    .background(Color.loopedBackground)
}
