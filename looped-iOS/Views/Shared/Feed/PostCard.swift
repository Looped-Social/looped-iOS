import SwiftUI
import UIKit

struct PostCard: View {
    let post: Post
    let showsCommunityLabel: Bool
    let showsAppealPostRemoval: Bool
    let showsRepostBanner: Bool
    let telemetryFeedContext: TelemetryFeedContext?
    let telemetryEntryPoint: String?
    let onBookmarkToggle: ((Bool) -> Void)?
    let onUpdate: ((Post) -> Void)?
    let onDelete: ((Post) -> Void)?
    let onBlockUser: ((Int) -> Void)?
    let onBlockPrincipal: ((Int) -> Void)?
    let onPresentLockedActionSheet: ((LockedActionSheetRequest) -> Void)?
    let onAuthorNavigationRequested: ((Int, Bool) -> Void)?
    let onCommunityNavigationRequested: ((CommunityProfileData) -> Void)?
    private let feedService: FeedServiceProtocol
    private let communityService: CommunityServiceProtocol
    @State private var isLiked = false
    @State private var isReposted = false
    @State private var isBookmarked = false
    @State private var isBookmarkLoading = false
    @State private var isLikeLoading = false
    @State private var isRepostLoading = false
    @State private var showHeartBurst = false
    @State private var heartScale: CGFloat = 0.6
    @State private var heartOpacity: Double = 0
    @State private var communityPermissions: CommunityPermissions?
    @State private var hasRequestedCommunityPermissions = false
	    @State private var viewerAnonProfileId: Int?
	    @State private var showShareSheet = false
        @State private var isPreparingShareSheet = false
        @State private var shareItems: [Any] = []
	    @State private var isShareTracking = false
    @State private var selectedImageUrl: String?
    @State private var selectedImageIndex: Int = 0
    @State private var showImageViewer = false
    @State private var selectedVideo: VideoSelection?
    @StateObject private var postActionState = PostActionBarState()
    @ScaledMetric private var actionIconSize: CGFloat = 22
    @ScaledMetric private var repostIconSize: CGFloat = 26
    @ScaledMetric private var actionLabelSpacing: CGFloat = 4
    @ScaledMetric private var engagementBarSpacing: CGFloat = 10
    @EnvironmentObject var commentsManager: CommentsModalManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @Environment(\.loopedOpenHashtag) private var openHashtag
    @Environment(\.loopedOpenMention) private var openMention
    @Environment(\.loopedPresentToast) private var presentToast
    @AppStorage("anonymousMode") private var isAnonymousMode = false
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames
    @State private var showActionMenu = false
    @State private var showBlockConfirm = false
    @State private var activeModerationSheet: ModerationSheet?
    @State private var moderationAlertMessage: String?
    @State private var blockAlertMessage: String?
    @State private var blockErrorMessage: String?
    @State private var isBlocking = false
    @State private var isDeleting = false
		    @State private var showEditSheet = false
		    @State private var editText = ""
		    @State private var editRemoveMedia = false
		    @State private var isEditing = false
		    @State private var repostErrorMessage: String?
		    @State private var actionError: PostActionError?
	        @State private var isJoiningSpecialization = false
	    @State private var showRepostersSheet = false
    @State private var lockedActionSheetState: LockedActionSheetState?
    @State private var lockedActionToastState: LockedActionToastState?
    @State private var lockedActionToastTask: Task<Void, Never>?
    @State private var lockCommunityDetails: CommunityProfileData?
    @State private var verificationTargetCommunity: CommunityProfileData?
    @State private var verificationFlowDidComplete = false
    @State private var showVerificationCommunityPicker = false
    @State private var showLockedActionHowItWorks = false
    @State private var pendingLockedActionRetry: LockedFeedActionType?
    @State private var pendingJoinAfterVerificationCommunityId: Int?
    @State private var lockedActionSheetDetent: PresentationDetent = PostCard.lockedActionDefaultDetent
    @State private var lockedActionSheetDismissalIntent: LockedActionSheetDismissalIntent = .none

    private static let lockedActionDefaultDetent: PresentationDetent = .height(292)

    private enum LockedActionSheetDismissalIntent {
        case none
        case unlockFlow
        case showHowItWorks
    }

		    private let moderationService: ModerationServiceProtocol = ModerationService()
		    private let blockService: BlockServiceProtocol = BlockService()

    init(
        post: Post,
        feedService: FeedServiceProtocol = FeedService(),
        communityService: CommunityServiceProtocol = CommunityService(),
        showsCommunityLabel: Bool = false,
        showsAppealPostRemoval: Bool = false,
        showsRepostBanner: Bool = false,
        telemetryFeedContext: TelemetryFeedContext? = nil,
        telemetryEntryPoint: String? = nil,
        onBookmarkToggle: ((Bool) -> Void)? = nil,
        onUpdate: ((Post) -> Void)? = nil,
        onDelete: ((Post) -> Void)? = nil,
        onBlockUser: ((Int) -> Void)? = nil,
        onBlockPrincipal: ((Int) -> Void)? = nil,
        onPresentLockedActionSheet: ((LockedActionSheetRequest) -> Void)? = nil,
        onAuthorNavigationRequested: ((Int, Bool) -> Void)? = nil,
        onCommunityNavigationRequested: ((CommunityProfileData) -> Void)? = nil
    ) {
        self.post = post
        self.feedService = feedService
        self.communityService = communityService
        self.showsCommunityLabel = showsCommunityLabel
        self.showsAppealPostRemoval = showsAppealPostRemoval
        self.showsRepostBanner = showsRepostBanner
        self.telemetryFeedContext = telemetryFeedContext
        self.telemetryEntryPoint = telemetryEntryPoint
        self.onBookmarkToggle = onBookmarkToggle
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onBlockUser = onBlockUser
        self.onBlockPrincipal = onBlockPrincipal
        self.onPresentLockedActionSheet = onPresentLockedActionSheet
        self.onAuthorNavigationRequested = onAuthorNavigationRequested
        self.onCommunityNavigationRequested = onCommunityNavigationRequested
    }

    private var repostBannerText: String? {
        guard showsRepostBanner else { return nil }
        let count = post.repostedByFollowedUsersCount ?? post.repostedByFollowedUsers?.count ?? 0
        guard count > 0 else { return nil }
        let names = (post.repostedByFollowedUsers ?? []).map(\.username)

        if count == 1, let first = names.first {
            return "\(first) reposted this"
        }
        if count == 2, names.count >= 2 {
            return "\(names[0]) and \(names[1]) reposted this"
        }
        if count > 2, names.count >= 2 {
            let remaining = max(count - 2, 0)
            return "\(names[0]), \(names[1]), and \(remaining) more reposted this"
        }
        if count > 1, let first = names.first {
            let remaining = max(count - 1, 0)
            return "\(first) and \(remaining) others reposted this"
        }
        return "Reposted by \(count) people"
    }

    private var imageUrls: [String] {
        post.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    private var postHasEditableMedia: Bool {
        if let mediaAssetId = post.mediaAssetId, mediaAssetId > 0 {
            return true
        }
        if let mediaAssetIds = post.mediaAssetIds, mediaAssetIds.contains(where: { $0 > 0 }) {
            return true
        }
        if let attachments = post.attachments, !attachments.isEmpty {
            return true
        }
        return false
    }

    private var editSheetCommunityLabel: String {
        if let name = post.communityDisplayName(preferShortNames: preferCommunityShortNames) {
            return name
        }
        if let kind = post.communityKind, kind != .unknown {
            return kind.rawValue.capitalized
        }
        return "Current community"
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

    private var displayedReactionCount: Int {
        let base = post.reactionCount
        if isLiked, post.userReaction != .like {
            return base + 1
        }
        if !isLiked, post.userReaction == .like {
            return max(base - 1, 0)
        }
        return base
    }

    private var viewerCapabilities: PostViewerCapabilities? {
        guard !isAnonymousMode else { return nil }
        return post.viewerCapabilities
    }

    private var authorDisplayLine: String? {
        post.authorDisplaySpecializationLine(preferShortNames: preferCommunityShortNames)
    }

    private var communityContextText: String? {
        guard showsCommunityLabel else { return nil }
        if let name = post.communityDisplayName(preferShortNames: preferCommunityShortNames) {
            return "Posted in \(name)"
        }
        if let kind = post.communityKind, kind != .unknown {
            return "Posted in \(kind.rawValue.capitalized)"
        }
        return nil
    }

    private var communityProfileData: CommunityProfileData? {
        guard let communityId = post.communityId else { return nil }
        let trimmedName = post.communityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedName = trimmedName.isEmpty
            ? post.communityKind?.rawValue.capitalized ?? "Community"
            : trimmedName
        return CommunityProfileData(
            id: communityId,
            name: resolvedName,
            shortName: post.communityShortName?.trimmedNonEmpty,
            description: "",
            kind: post.communityKind ?? .unknown,
            specializationType: .unknown,
            memberCount: 0,
            imageUrl: nil,
            isFollowing: false,
            isJoined: false
        )
    }

    private var authorProfileId: Int? {
        if post.isAnonymous {
            return post.anonProfileId
        }
        return post.authorBackendId ?? post.authorId.backendInt
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let authorProfileId, let onAuthorNavigationRequested {
            Button(action: { onAuthorNavigationRequested(authorProfileId, post.isAnonymous) }) {
                avatarContent
            }
            .buttonStyle(.plain)
        } else if let authorProfileId {
            NavigationLink(destination: authorProfileDestination(profileId: authorProfileId)) {
                avatarContent
            }
            .buttonStyle(.plain)
        } else {
            Button(action: presentMissingAuthorProfileError) {
                avatarContent
            }
            .buttonStyle(.plain)
        }
    }

    private var avatarContent: some View {
        ProfileAvatarView(
            imageURL: post.authorProfileImageURL,
            size: 46,
            variant: post.isAnonymous ? .anonymous : .standard
        )
    }

    @ViewBuilder
    private var authorName: some View {
        if let authorProfileId, let onAuthorNavigationRequested {
            Button(action: { onAuthorNavigationRequested(authorProfileId, post.isAnonymous) }) {
                Text(post.resolvedAuthorName)
                    .font(.loopedHeadlineScaled)
                    .foregroundColor(post.isAnonymous ? .loopedSecondary : .loopedTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(.plain)
        } else if let authorProfileId {
            NavigationLink(destination: authorProfileDestination(profileId: authorProfileId)) {
                Text(post.resolvedAuthorName)
                    .font(.loopedHeadlineScaled)
                    .foregroundColor(post.isAnonymous ? .loopedSecondary : .loopedTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: presentMissingAuthorProfileError) {
                Text(post.resolvedAuthorName)
                    .font(.loopedHeadlineScaled)
                    .foregroundColor(post.isAnonymous ? .loopedSecondary : .loopedTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .buttonStyle(.plain)
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

		    @ViewBuilder
		    private var repostBanner: some View {
		        if let repostBannerText {
		            Button(action: { showRepostersSheet = true }) {
		                HStack(spacing: 8) {
		                    Image(systemName: "arrow.2.squarepath")
		                        .font(.loopedCustom(.medium, size: 14))
		                        .foregroundColor(.loopedTextSecondary)

		                    Text(repostBannerText)
		                        .font(.loopedSmallText)
		                        .foregroundColor(.loopedTextSecondary)
		                        .lineLimit(1)
		                        .truncationMode(.tail)

		                    Spacer(minLength: 0)
		                }
		                .contentShape(Rectangle())
		            }
		            .buttonStyle(PlainButtonStyle())
		            .padding(.bottom, 2)
		            .sheet(isPresented: $showRepostersSheet) {
		                NavigationStack {
		                    RepostersListView(
                                postId: post.backendId,
		                        users: post.repostedByFollowedUsers ?? [],
		                        totalCount: post.repostedByFollowedUsersCount ?? post.repostedByFollowedUsers?.count ?? 0
		                    )
		                }
		            }
		        }
		    }

    private var likeButton: some View {
        Button(action: { handleLikeToggle() }) {
            HStack(spacing: actionLabelSpacing) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: actionIconSize, height: actionIconSize)
                            .foregroundColor(isLiked ? .loopedError : .loopedTextSecondary)

                        if isReactionLocked {
                            Image(systemName: "lock.fill")
                                .font(.loopedCustom(.bold, size: 10))
                                .foregroundColor(.loopedTextSecondary)
                                .padding(3)
                                .background(Circle().fill(Color.loopedBackground))
                                .offset(x: 7, y: -7)
                        }
                    }
	                Text("\(displayedReactionCount)")
                    .font(.loopedSubheadlineScaled)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }

    private var shareButton: some View {
        Button(action: { prepareShareSheet() }) {
            Image("send-icon-fab")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: actionIconSize, height: actionIconSize)
                .foregroundColor(.loopedTextSecondary)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .disabled(isPreparingShareSheet)
        .opacity(isPreparingShareSheet ? 0.6 : 1)
    }

    private var repostButton: some View {
        Button(action: { toggleRepost() }) {
	            HStack(spacing: actionLabelSpacing) {
                    Image(systemName: "arrow.2.squarepath")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: repostIconSize, height: repostIconSize)
                        .foregroundColor(isReposted ? .loopedPrimary : .loopedTextSecondary)
                        .opacity(isRepostLoading ? 0.6 : 1)
	            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .disabled(isRepostLoading)
    }

	    private var commentButton: some View {
	        Button(action: { openCommentsIfPossible() }) {
	            HStack(spacing: actionLabelSpacing) {
	                Image("comment-icon")
	                    .resizable()
	                    .renderingMode(.template)
	                    .scaledToFit()
	                    .frame(width: actionIconSize, height: actionIconSize)
	                    .foregroundColor(.loopedTextSecondary)
	                Text("\(post.commentsCount)")
	                    .font(.loopedSubheadlineScaled)
	                    .foregroundColor(.loopedTextSecondary)
	            }
	        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
	    }

    private var bookmarkButton: some View {
        Button(action: { toggleBookmark() }) {
	            Image(isBookmarked ? "saved-icon" : "save-icon")
	                .resizable()
	                .renderingMode(.template)
	                .scaledToFit()
	                .frame(width: actionIconSize, height: actionIconSize)
	                .foregroundColor(isBookmarked ? .loopedPrimary : .loopedTextSecondary)
	                .opacity(isBookmarkLoading ? 0.6 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .disabled(isBookmarkLoading)
    }

		    private var engagementBar: some View {
		        HStack(spacing: engagementBarSpacing) {
		            likeButton
		            commentButton
		            repostButton
		            shareButton
		            Spacer()
		            bookmarkButton
		        }
                .contentShape(Rectangle())
                .zIndex(10)
		    }

			    @ViewBuilder
			    private var headerSection: some View {
			        HStack(alignment: .top, spacing: 12) {
		            if !post.isAnonymous {
		                authorAvatar
				    }

		            VStack(alignment: .leading, spacing: 0) {
		                HStack(spacing: 6) {
		                    authorName
                                .layoutPriority(1)

		                    if let authorDisplayLine {
		                        Text("•")
		                            .font(.loopedSubheadlineScaled)
		                            .foregroundColor(.loopedTextSecondary)
		                        Text(authorDisplayLine)
		                            .font(.loopedSubheadlineScaled)
		                            .foregroundColor(.loopedTextSecondary)
		                            .lineLimit(1)
		                            .truncationMode(.tail)
		                    }

		                    Spacer()

		                    Button(action: { showActionMenu = true }) {
		                        Image(systemName: "ellipsis")
                                    .font(.loopedSymbol(.regular, size: 17))
                                    .scaleEffect(1.5)
		                            .foregroundColor(.loopedTextSecondary)
		                    }
                            .contentShape(Rectangle().inset(by: -14))
                            .accessibilityLabel("Post options")
		                }

		                if let communityContextText {
			                    if let communityProfileData, let onCommunityNavigationRequested {
			                        Button(action: { onCommunityNavigationRequested(communityProfileData) }) {
			                            HStack(spacing: 0) {
			                                Text(communityContextText)
			                                    .lineLimit(1)
			                                    .truncationMode(.tail)
			                                Spacer(minLength: 0)
				                            }
				                            .font(.loopedSubBodyRegular)
				                            .foregroundColor(.loopedTextSecondary)
				                            .padding(.top, -2)
				                            .contentShape(Rectangle())
				                        }
				                        .buttonStyle(.plain)
				                    } else if let communityProfileData {
				                        NavigationLink(destination: CommunityProfileView(community: communityProfileData)) {
				                            HStack(spacing: 0) {
				                                Text(communityContextText)
				                                    .lineLimit(1)
				                                    .truncationMode(.tail)
				                                Spacer(minLength: 0)
				                            }
				                            .font(.loopedSubBodyRegular)
				                            .foregroundColor(.loopedTextSecondary)
				                            .padding(.top, -2)
				                            .contentShape(Rectangle())
				                        }
				                        .buttonStyle(.plain)
				                    } else {
				                        Text(communityContextText)
				                            .font(.loopedSubBodyRegular)
				                            .foregroundColor(.loopedTextSecondary)
				                            .padding(.top, -2)
				                            .lineLimit(1)
				                            .truncationMode(.tail)
				                    }
			                }
			            }
			        }
                    .zIndex(10)
			    }

		    @ViewBuilder
			    private var postTextSection: some View {
		        let trimmedContent = post.content.trimmingCharacters(in: .whitespacesAndNewlines)
		        let shouldHideDuplicatePollQuestion: Bool = {
		            guard let poll = post.poll else { return false }
		            let trimmedQuestion = poll.question.trimmingCharacters(in: .whitespacesAndNewlines)
		            return !trimmedQuestion.isEmpty && trimmedContent == trimmedQuestion
		        }()

			        if !trimmedContent.isEmpty, !shouldHideDuplicatePollQuestion {
				            HashtagText(
				                text: trimmedContent,
				                font: .loopedBodyScaled,
				                textColor: .loopedTextPrimary,
				                hashtagColor: .loopedPrimary
				            ) { hashtag in
				                openHashtag(hashtag)
				            } onMentionTap: { handle in
                                openMention(handle)
				            }
				            .multilineTextAlignment(.leading)
                        .loopedDoubleTapToLike {
                            handleDoubleTapLike()
                        }
			        }
			    }

		    @ViewBuilder
			    private var pollSection: some View {
			        if let poll = post.poll {
                    PollCard(
                            poll: poll,
                            communityId: post.communityId,
                            communityName: post.communityName,
                            communityShortName: post.communityShortName,
                            communityKind: post.communityKind,
                            communityPermissions: communityPermissions,
                            viewerCapabilities: viewerCapabilities,
                            postBackendId: post.backendId,
                            telemetryFeedContext: telemetryFeedContext
                        ) { updatedPoll in
                            onUpdate?(post.updating(poll: .some(updatedPoll), updatedAt: Date()))
                    }
			            .padding(.top, 4)
			        }
			    }

			    @ViewBuilder
				    private var attachmentsSection: some View {
				        if let attachments = post.attachments, !attachments.isEmpty {
				            VStack(spacing: 0) {
			                Spacer()
			                    .frame(height: 12)

			                PostedMediaGrid(
			                    attachments: attachments,
			                    maxHeight: 350,
			                    onImageTap: handlePostedImageTap,
				                    onVideoTap: handlePostedVideoTap
				                )
				            }
                            .clipped()
				        }
				    }

			    private func handlePostedImageTap(_ url: String) {
			        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
			        guard !trimmed.isEmpty else { return }
			        if let index = imageUrls.firstIndex(of: url) {
			            selectedImageIndex = index
			        }
			        selectedImageUrl = url
			        DispatchQueue.main.async {
			            showImageViewer = true
			        }
			    }

    private func handlePostedVideoTap(_ selection: VideoSelection) {
        let trimmed = selection.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedVideo = VideoSelection(
            url: trimmed,
            thumbnailUrl: selection.thumbnailUrl,
            authorName: post.resolvedAuthorName,
            authorImageUrl: post.authorProfileImageURL,
            communityName: communityContextText,
            caption: post.content,
            inlineId: selection.inlineId,
            inlineViewModel: selection.inlineViewModel,
            postActionConfig: postActionBarConfig
        )
    }

		    private var timestampSection: some View {
		        HStack {
		            Text(formattedTimeAgo)
		                .font(.loopedSubheadlineScaled)
		                .foregroundColor(.loopedTextSecondary)
		            Spacer()
		        }
		    }

				    private var shareSheetContent: some View {
				        ShareSheet(
	                        items: shareItems.isEmpty ? defaultShareItems : shareItems
	                    ) { completed, activityType in
				            if shouldTrackShare(completed: completed, activityType: activityType) {
				                trackShare()
				            }
				        }
				    }

    @ViewBuilder
    private var imageViewerContent: some View {
        if !imageUrls.isEmpty {
            FullScreenImageViewer(
                imageUrls: imageUrls,
                initialIndex: selectedImageIndex,
                isPresented: $showImageViewer,
                postActionConfig: postActionBarConfig,
                onShare: prepareShareSheet
            )
        } else {
            Color.loopedBlack.ignoresSafeArea()
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.loopedCustom(size: 60))
                            .foregroundColor(.loopedWhite.opacity(0.5))
                        Text("No images available")
                            .foregroundColor(.loopedWhite.opacity(0.7))
                        Button("Close") {
                            showImageViewer = false
                        }
                        .foregroundColor(.loopedWhite)
                        .padding()
                        .background(Color.loopedWhite.opacity(0.2))
                        .cornerRadius(8)
                    }
                )
        }
    }

    private var videoPlayerBinding: Binding<Bool> {
        Binding(
            get: { selectedVideo != nil },
            set: { if !$0 { selectedVideo = nil } }
        )
    }

    private var postActionBarConfig: PostActionBarConfig {
        PostActionBarConfig(
            state: postActionState,
            onLike: { handleLikeToggle() },
            onComment: { openCommentsIfPossible() },
            onRepost: toggleRepost,
            onShare: prepareShareSheet,
            onSave: toggleBookmark
        )
    }

		    @ViewBuilder
		    private var postOptionsDialogActions: some View {
		        if canEditPost {
		            Button("Edit Post") {
		                editText = post.content
                        editRemoveMedia = false
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
		        if canBlockUser {
		            Button("Block User", role: .destructive) {
		                showBlockConfirm = true
		            }
		        }
		        if canAppealPostRemoval {
		            Button("Appeal Post Removal") {
		                activeModerationSheet = .appealPostRemoval
		            }
		        }
		        Button("Cancel", role: .cancel) { }
		    }

		    @ViewBuilder
		    private func moderationSheetContent(_ sheet: ModerationSheet) -> some View {
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

		    private var editSheetContent: some View {
		        EditPostSheet(
		            text: $editText,
                    removeMedia: $editRemoveMedia,
                    hasMedia: postHasEditableMedia,
                    hasPoll: post.poll != nil,
                    communityLabel: editSheetCommunityLabel,
		            isSaving: isEditing,
		            onCancel: {
                        editRemoveMedia = false
                        showEditSheet = false
                    },
		            onSave: { Task { await updatePost() } }
		        )
		    }

    private var moderationAlertIsPresented: Binding<Bool> {
        Binding(
            get: { moderationAlertMessage != nil },
            set: { if !$0 { moderationAlertMessage = nil } }
        )
    }

    private var blockAlertIsPresented: Binding<Bool> {
        Binding(
            get: { blockAlertMessage != nil },
            set: { if !$0 { blockAlertMessage = nil } }
        )
    }

    private var blockErrorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { blockErrorMessage != nil },
            set: { if !$0 { blockErrorMessage = nil } }
        )
    }

    private var repostErrorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { repostErrorMessage != nil },
            set: { if !$0 { repostErrorMessage = nil } }
        )
    }

    var body: some View {
        postCardAlerts
    }

			    private var postCardContent: some View {
			        ZStack {
			            VStack(alignment: .leading, spacing: 12) {
			                repostBanner
			                underReviewBanner
			                headerSection
			                postTextSection
			                pollSection
			                attachmentsSection
			                engagementBar
			                timestampSection
			            }

            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.loopedCustom(.bold, size: 72))
                    .foregroundColor(.loopedError)
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
                    .allowsHitTesting(false)
            }
        }
    }

		    private var postCardStyled: some View {
		        postCardContent
                    .frame(maxWidth: .infinity, alignment: .leading)
		            .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
		            .background(Color.loopedBackground)
		            .cornerRadius(0)
                    .clipped()
		    }

    private var postCardLifecycle: some View {
        let base = postCardStyled
            .onAppear {
                syncBookmarkState()
                syncLikeState()
                syncRepostState()
                syncActionBarState()
                Task { await syncViewerAnonProfileId() }
                Task { await loadCommunityPermissionsIfNeeded() }
            }
            .onChange(of: isAnonymousMode) { _, _ in
                Task { await syncViewerAnonProfileId() }
                hasRequestedCommunityPermissions = false
                Task { await loadCommunityPermissionsIfNeeded() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .communityStateChanged)) { notification in
                guard shouldLoadCommunityPermissions else { return }
                guard let communityId = post.communityId, communityId > 0 else { return }
                if let changed = notification.userInfo?[LoopedNotificationUserInfoKey.communityId] as? Int,
                   changed != communityId {
                    return
                }
                Task { await refreshCommunityPermissions() }
            }

        let postChanges = base
            .onChange(of: post.userReaction) { _, _ in
                syncLikeState()
                syncActionBarState()
            }
            .onChange(of: post.viewerHasReposted) { _, _ in
                syncRepostState()
                syncActionBarState()
            }
            .onChange(of: post.isSaved) { _, _ in
                syncBookmarkState()
                syncActionBarState()
            }
            .onChange(of: post.reactionCount) { _, _ in
                syncActionBarState()
            }
            .onChange(of: post.commentsCount) { _, _ in
                syncActionBarState()
            }

        let localChanges = postChanges
            .onChange(of: isLiked) { _, _ in
                syncActionBarState()
            }
            .onChange(of: isReposted) { _, _ in
                syncActionBarState()
            }
            .onChange(of: isBookmarked) { _, _ in
                syncActionBarState()
            }

        return localChanges
            .onChange(of: isRepostLoading) { _, _ in
                syncActionBarState()
            }
            .onChange(of: isBookmarkLoading) { _, _ in
                syncActionBarState()
            }
            .onChange(of: isPreparingShareSheet) { _, _ in
                syncActionBarState()
            }
            .onChange(of: isReactionLocked) { _, _ in
                syncActionBarState()
            }
            .onDisappear {
                lockedActionToastTask?.cancel()
            }
    }

    @MainActor
    private func refreshCommunityPermissions() async {
        guard shouldLoadCommunityPermissions else { return }
        guard let communityId = post.communityId, communityId > 0 else { return }
        await CommunityPermissionsCache.shared.invalidate(communityId: communityId)
        communityPermissions = await CommunityPermissionsCache.shared.permissions(communityId: communityId)
        hasRequestedCommunityPermissions = true
    }

    private var postCardPresentation: some View {
        postCardLifecycle
            .sheet(isPresented: $showShareSheet, onDismiss: {
                    shareItems = []
                }) {
	                shareSheetContent
	            }
	            .fullScreenCover(isPresented: $showImageViewer, onDismiss: {
	                selectedImageUrl = nil
            }) {
                imageViewerContent
            }
            .fullScreenCover(item: $selectedVideo) { selection in
                VideoPlayerSheet(selection: selection, isPresented: videoPlayerBinding)
            }
    }

	    private var blockConfirmDialogMessage: some View {
	        Text("You won't see posts from \(blockTargetLabel) anymore.")
	    }

	    private var postCardDialogs: some View {
	        postCardPresentation
	            .confirmationDialog(
	                "Post options",
	                isPresented: $showActionMenu,
	                titleVisibility: .visible
	            ) {
                postOptionsDialogActions
            }
            .confirmationDialog(
                "Block user?",
                isPresented: $showBlockConfirm,
                titleVisibility: .visible
            ) {
                Button("Block User", role: .destructive) {
                    Task { await blockUser() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                blockConfirmDialogMessage
            }
    }

	    private var postCardSheets: some View {
	        postCardDialogs
	            .sheet(item: $activeModerationSheet) { sheet in
	                moderationSheetContent(sheet)
	            }
            .sheet(isPresented: $showEditSheet) {
                editSheetContent
            }
            .sheet(
                item: $lockedActionSheetState,
                onDismiss: {
                    switch lockedActionSheetDismissalIntent {
                    case .unlockFlow:
                        lockedActionSheetDismissalIntent = .none
                        return
                    case .showHowItWorks:
                        lockedActionSheetDismissalIntent = .none
                        showLockedActionHowItWorks = true
                        return
                    case .none:
                        pendingLockedActionRetry = nil
                        lockedActionSheetState = nil
                    }
                }
            ) { state in
                GeometryReader { _ in
                    LockedActionSheet(
                        reason: state.reason,
                        actionType: state.actionType,
                        isPrimaryLoading: isJoiningSpecialization,
                        onPrimary: {
                            lockedActionSheetDismissalIntent = .unlockFlow
                            handleLockedActionPrimary(reason: state.reason, actionType: state.actionType)
                        },
                        onHowItWorks: {
                            lockedActionSheetDismissalIntent = .showHowItWorks
                            pendingLockedActionRetry = nil
                            lockedActionSheetState = nil
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .background(
                    SheetPresentationConfigurator { sheet in
                        sheet.prefersEdgeAttachedInCompactHeight = true
                        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = false
                    }
                )
                .presentationDetents(
                    [PostCard.lockedActionDefaultDetent, .large],
                    selection: $lockedActionSheetDetent
                )
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.loopedBackground)
            }
            .sheet(
                item: $verificationTargetCommunity,
                onDismiss: {
                    Task { @MainActor in
                        guard verificationFlowDidComplete == false else {
                            verificationFlowDidComplete = false
                            return
                        }
                        await handleVerificationFlowDismissed()
                    }
                }
            ) { community in
                CommunityVerificationFlowView(
                    community: community,
                    onComplete: { completion in
                        verificationFlowDidComplete = true
                        Task { @MainActor in
                            await handleVerificationFlowCompleted(community: community, completion: completion)
                        }
                    }
                )
                .environmentObject(authViewModel)
            }
            .sheet(
                isPresented: $showVerificationCommunityPicker,
                onDismiss: {
                    Task { @MainActor in
                        await handleVerificationPickerDismissed()
                    }
                }
            ) {
                NavigationStack {
                    CommunityVerificationsView()
                        .environmentObject(authViewModel)
                }
            }
            .sheet(isPresented: $showLockedActionHowItWorks) {
                NavigationStack {
                    VerificationInfoScreen(closeButtonStyle: .xmark)
                }
            }
	    }

	    private var postCardAlerts: some View {
	        postCardSheets
            .alert("Thanks", isPresented: moderationAlertIsPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(moderationAlertMessage ?? "")
            }
            .alert("User blocked", isPresented: blockAlertIsPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(blockAlertMessage ?? "")
            }
            .alert("Couldn't block user", isPresented: blockErrorAlertIsPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(blockErrorMessage ?? "")
            }
	            .alert("Couldn't repost", isPresented: repostErrorAlertIsPresented) {
	                Button("OK", role: .cancel) { }
	            } message: {
	                Text(repostErrorMessage ?? "")
	            }
		            .alert(item: $actionError) { error in
	                    if let action = error.primaryAction {
	                        return Alert(
	                            title: Text(error.title),
	                            message: Text(error.message),
                            primaryButton: .default(Text("Join")) {
                                handlePrimaryAction(action)
                            },
                            secondaryButton: .cancel()
                        )
                    }
		                return Alert(
		                    title: Text(error.title),
		                    message: Text(error.message),
		                    dismissButton: .default(Text("OK"))
		                )
		            }
	    }

    private var canonicalPostURL: URL? {
        guard let postId = post.backendId else { return nil }
        return URL(string: "https://mylooped.app/p/\(postId)")
    }

    private var defaultShareItems: [Any] {
        if let canonicalPostURL {
            return [canonicalPostURL]
        }
        return ["Check this out on Looped"]
    }

        private func prepareShareSheet() {
            guard !isPreparingShareSheet else { return }
            isPreparingShareSheet = true

            Task { @MainActor in
                defer { isPreparingShareSheet = false }
                shareItems = defaultShareItems
                showShareSheet = true
            }
        }

    private func shouldTrackShare(completed: Bool, activityType: UIActivity.ActivityType?) -> Bool {
        guard completed else { return false }
        if activityType == .copyToPasteboard {
            // Keep copy available in the sheet, but don't count it as a successful share.
            return false
        }
        return post.backendId != nil
    }

    private func trackShare() {
        guard let postId = post.backendId, !isShareTracking else { return }
        isShareTracking = true
        Task {
            defer { isShareTracking = false }
            do {
                _ = try await feedService.sharePost(postId: postId)
                LoopedHaptics.success()
            } catch {
                if isNotFound(error) {
                    handleContentUnavailable()
                    return
                }
                actionError = PostActionError(
                    title: "Couldn't share post",
                    message: actionErrorMessage(verb: "share", error: error)
                )
            }
        }
    }

    private func toggleBookmark() {
        guard !isBookmarkLoading else { return }
        guard let postId = post.backendId else {
            presentMissingPostIdError(action: "save this post")
            return
        }
        if isSaveLocked {
            actionError = PostActionError(
                title: reactionLockTitle,
                message: reactionLockMessage(verb: "save posts"),
                primaryAction: joinPrimaryAction
            )
            return
        }
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
                        let updated = post.updating(isSaved: false, updatedAt: Date())
                        onUpdate?(updated)
                        onBookmarkToggle?(false)
                        presentToast(ToastMessage(text: "Removed from saved posts.", kind: .success))
                    }
                } else {
                    let saved = try await feedService.savePost(
                        postId: postId,
                        communityId: post.communityId
                    )
                    if saved {
                        isBookmarked = true
                        let updated = post.updating(isSaved: true, updatedAt: Date())
                        onUpdate?(updated)
                        onBookmarkToggle?(true)
                        presentToast(ToastMessage(text: "Post saved.", kind: .success))
	                    }
	                }
	            } catch {
                    if isNotFound(error) {
                        handleContentUnavailable()
                        return
                    }
	                let title = isBookmarked ? "Couldn't remove saved post" : "Couldn't save post"
	                actionError = PostActionError(
	                    title: title,
	                    message: actionErrorMessage(verb: "update saved posts", error: error)
	                )
	            }
	        }
	    }

    private func deletePost() async {
        guard !isDeleting else { return }
        guard let postId = post.backendId else {
            presentMissingPostIdError(action: "delete this post")
            return
        }
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
                presentToast(ToastMessage(text: "Post deleted.", kind: .success))
            } else {
                presentToast(ToastMessage(text: "Couldn't delete post. Try again.", kind: .error))
            }
        } catch {
            if isNotFound(error) {
                handleContentUnavailable()
                return
            }
            presentToast(ToastMessage(text: "Couldn't delete post. \(error.localizedDescription)", kind: .error))
        }
    }

    private func updatePost() async {
        guard !isEditing else { return }
        guard let postId = post.backendId else {
            presentMissingPostIdError(action: "edit this post")
            return
        }
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isEditing = true
        defer { isEditing = false }
        do {
            let updated = try await feedService.updatePost(
                postId: postId,
                content: trimmed,
                isAnonymous: post.isAnonymous,
                communityId: post.communityId,
                removeMedia: editRemoveMedia && postHasEditableMedia
            )
            onUpdate?(updated)
            editRemoveMedia = false
            showEditSheet = false
            presentToast(ToastMessage(text: "Post updated.", kind: .success))
        } catch {
            if post.isAnonymous, isContentUnderReview(error) {
                showEditSheet = false
                actionError = PostActionError(
                    title: "Under review",
                    message: "Your edit is under review."
                )
                return
            }
            if isNotFound(error) {
                showEditSheet = false
                handleContentUnavailable()
                return
            }
            presentToast(ToastMessage(text: "Couldn't update post. \(error.localizedDescription)", kind: .error))
        }
    }

    private var blockTargetLabel: String {
        if post.isAnonymous {
            return "this user"
        }
        let trimmedHandle = (post.authorHandle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHandle.isEmpty {
            return "@\(trimmedHandle)"
        }
        let name = post.resolvedAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "this user" : name
    }

    private func blockUser() async {
        guard !isBlocking else { return }
        isBlocking = true
        defer { isBlocking = false }

        do {
            if let authorId = post.authorBackendId {
                _ = try await blockService.blockUser(
                    userId: authorId,
                    asAnonymousActor: isAnonymousMode,
                    communityId: post.communityId
                )
                onBlockUser?(authorId)
            } else if let principalId = post.authorPrincipalId {
                _ = try await blockService.blockPrincipal(
                    principalId: principalId,
                    asAnonymousActor: isAnonymousMode,
                    communityId: post.communityId
                )
                onBlockPrincipal?(principalId)
            } else {
                throw ModerationError.missingTarget
            }
            NotificationCenter.default.post(name: .contentPreferencesChanged, object: nil)
            blockAlertMessage = "You won't see posts from \(blockTargetLabel) anymore."
        } catch {
            blockErrorMessage = error.localizedDescription
        }
    }

    private func initials(from name: String?) -> String {
        guard let name = name, let first = name.split(separator: " ").first?.first else {
            return "U"
        }
        return String(first).uppercased()
    }

    private func handleLikeToggle(allowRetryBypass: Bool = false) {
        if isReactionLocked && !allowRetryBypass {
            trackBlockedInteraction(.like)
            Task { await resolveLockedAction(.like) }
            return
        }
        performLikeToggle()
    }

    private func performLikeToggle() {
        guard !isLikeLoading else { return }
        guard let postId = post.backendId else {
            presentMissingPostIdError(action: "like this post")
            return
        }
        if isLiked {
            isLiked = false
            isLikeLoading = true
            Task {
                defer { isLikeLoading = false }
                do {
                    let response = try await feedService.unlikePost(
                        postId: postId,
                        communityId: post.communityId
                    )
                    let updated = post.updating(
                        reactionCount: response.likesCount,
                        userReaction: .some(nil),
                        updatedAt: Date()
                    )
                    onUpdate?(updated)
                } catch {
                    isLiked = true
                    if isNotFound(error) {
                        handleContentUnavailable()
                        return
                    }
                    presentLikeErrorIfNeeded(verb: "unlike", title: "Couldn't unlike post", error: error)
                }
            }
            return
        }

        isLiked = true
        triggerHeartBurst()
        isLikeLoading = true
        Task {
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
                LoopedHaptics.success()
            } catch {
                isLiked = false
                if isNotFound(error) {
                    handleContentUnavailable()
                    return
                }
                presentLikeErrorIfNeeded(verb: "like", title: "Couldn't like post", error: error)
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

    private func syncBookmarkState() {
        guard !isBookmarkLoading else { return }
        isBookmarked = post.isSaved
    }

    private func syncRepostState() {
        guard !isRepostLoading else { return }
        isReposted = post.viewerHasReposted
    }

    private func syncActionBarState() {
        postActionState.likeCount = displayedReactionCount
        postActionState.commentCount = post.commentsCount
        postActionState.isLiked = isLiked
        postActionState.isReposted = isReposted
        postActionState.isSaved = isBookmarked
        postActionState.isRepostLoading = isRepostLoading
        postActionState.isBookmarkLoading = isBookmarkLoading
        postActionState.isPreparingShareSheet = isPreparingShareSheet
        postActionState.isReactionLocked = isReactionLocked
    }

    private func toggleRepost() {
        guard !isRepostLoading else { return }
        guard let postId = post.backendId else {
            presentMissingPostIdError(action: "repost")
            return
        }
        let previousValue = isReposted
        isReposted.toggle()
        isRepostLoading = true

        Task {
            defer { isRepostLoading = false }
            do {
                let response: PostRepostResponse
                if previousValue {
                    response = try await feedService.unrepostPost(postId: postId)
                } else {
                    response = try await feedService.repostPost(postId: postId)
                }

                let updated = post.updating(
                    viewerHasReposted: response.viewerHasReposted,
                    updatedAt: Date()
                )
                onUpdate?(updated)
                isReposted = response.viewerHasReposted
            } catch {
                isReposted = previousValue
                if isNotFound(error) {
                    handleContentUnavailable()
                    return
                }
                repostErrorMessage = repostErrorMessage(for: error)
            }
        }
    }

	    private func repostErrorMessage(for error: Error) -> String {
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

    private func actionErrorMessage(verb: String, error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return "Please sign in again and try to \(verb)."
            case .apiError(_, let error, let message):
                    if error == "community_not_verified" {
                        return "Verify in \(resolvedPostCommunityName()) to \(verb)."
	                }
                    if error == "specialization_not_joined" {
                        return "Join \(resolvedPostCommunityName()) to \(verb)."
                    }
                    if error == "specialization_verification_required" {
                        return "Verify first, then join this major or field to \(verb)."
                    }
	                return message ?? error
	            default:
	                return apiError.localizedDescription
	            }
	        }
	        return error.localizedDescription
	    }

    private func presentLikeErrorIfNeeded(verb: String, title: String, error: Error) {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized, .apiError, .serverError:
                if case .apiError(_, let code, _) = apiError,
                   code == "specialization_not_joined" || code == "specialization_verification_required" || code == "community_not_verified" {
                    Task { await resolveLockedAction(.like) }
                    return
                }
                actionError = PostActionError(
                    title: title,
                    message: actionErrorMessage(verb: verb, error: error)
                )
            default:
                break
            }
        }
    }

    private func handleContentUnavailable() {
        actionError = PostActionError(
            title: "Content unavailable",
            message: "This content is unavailable."
        )
        onDelete?(post)
    }

    private func isNotFound(_ error: Error) -> Bool {
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

    private func isContentUnderReview(_ error: Error) -> Bool {
        if case let APIError.apiError(code, apiError, _) = error {
            return code == 403 && apiError == "content_under_review"
        }
        return false
    }

    private var isReactionLocked: Bool {
        guard !isAnonymousMode else { return false }
        if let viewerCapabilities {
            return !viewerCapabilities.canInteract || !viewerCapabilities.canLike
        }
        guard shouldLoadCommunityPermissions else { return false }
        guard let communityPermissions else { return false }
        let requiresGate = communityPermissions.requiresVerification || communityPermissions.requiresJoin
        return requiresGate && !communityPermissions.canPost
    }

    private var isSaveLocked: Bool {
        guard !isAnonymousMode else { return false }
        if let viewerCapabilities {
            return !viewerCapabilities.canSave
        }
        return false
    }

    private func loadCommunityPermissionsIfNeeded() async {
        guard !hasRequestedCommunityPermissions else { return }
        guard shouldLoadCommunityPermissions else { return }
        hasRequestedCommunityPermissions = true
        guard let communityId = post.communityId, communityId > 0 else { return }
        communityPermissions = await CommunityPermissionsCache.shared.permissions(communityId: communityId)
    }

    private var shouldLoadCommunityPermissions: Bool {
        guard let communityId = post.communityId, communityId > 0 else { return false }
        guard !isAnonymousMode else { return false }
        return viewerCapabilities == nil
    }

    private var reactionLockTitle: String {
        if let viewerCapabilities {
            return viewerCapabilities.lockTitle(for: "interact")
        }
        guard let communityPermissions else { return "Action unavailable" }
        if communityPermissions.requiresJoin && !communityPermissions.canPost {
            return "Join required"
        }
        if communityPermissions.requiresVerification && !communityPermissions.canPost {
            return "Verification required"
        }
        return "Action unavailable"
    }

    private func reactionLockMessage(verb: String) -> String {
        if let viewerCapabilities {
            return viewerCapabilities.lockMessage(for: verb)
        }
        guard let communityPermissions else { return "You can’t \(verb) right now." }
        if communityPermissions.requiresJoin && !communityPermissions.canPost {
            return "Join \(resolvedPostCommunityName()) to \(verb)."
        }
        if communityPermissions.requiresVerification && !communityPermissions.canPost {
            return "Verify in \(resolvedPostCommunityName()) to \(verb)."
        }
        return "You can’t \(verb) right now."
    }

    private var telemetryLockReason: String? {
        if let viewerCapabilities {
            return viewerCapabilities.lockReason?.rawValue ?? PostViewerLockReason.unknownRestriction.rawValue
        }
        if let communityPermissions {
            if communityPermissions.requiresJoin && !communityPermissions.canPost {
                return PostViewerLockReason.specializationNotJoined.rawValue
            }
            if communityPermissions.requiresVerification && !communityPermissions.canPost {
                return PostViewerLockReason.communityNotVerified.rawValue
            }
        }
        return nil
    }

    private func trackBlockedInteraction(_ action: TelemetryInteractionAction) {
        guard let postId = post.backendId else { return }
        let lockReason = telemetryLockReason ?? PostViewerLockReason.unknownRestriction.rawValue
        Task {
            await TelemetryManager.shared.trackInteractionBlocked(
                postId: postId,
                feed: telemetryFeedContext,
                action: action,
                lockReason: lockReason
            )
        }
    }

    private func resolveLockedAction(_ actionType: LockedFeedActionType) async {
        let reason = await buildLockReason(for: actionType)
        await MainActor.run {
            presentLockedAction(reason: reason, actionType: actionType)
        }
    }

    private func buildLockReason(for _: LockedFeedActionType) async -> LockReason {
        let resolvedCommunityName = resolvedPostCommunityName()
        let lockContext = viewerCapabilities?.lockContext
        let primaryUnlockAction = viewerCapabilities?.primaryUnlockAction
        let resolvedLockCommunityName = normalizedOptional(lockContext?.communityName) ?? resolvedCommunityName
        let resolvedPostCommunityShortName = normalizedOptional(post.communityShortName)
        let resolvedSpecializationName = normalizedOptional(lockContext?.specializationName)
        let resolvedSpecializationType = lockContext?.specializationType ?? .unknown
        let fieldNameFromContext = resolvedSpecializationType == .field ? (resolvedSpecializationName ?? resolvedLockCommunityName) : nil
        let majorNameFromContext = resolvedSpecializationType == .major ? (resolvedSpecializationName ?? resolvedLockCommunityName) : nil
        let resolvedJoinCreditsRemaining = lockContext?.joinCreditsRemaining
        let resolvedAlreadyVerifiedElsewhere = lockContext?.alreadyVerifiedElsewhere ?? false
        let resolvedVerifyTargetCommunityId = primaryUnlockAction?.communityId ?? lockContext?.verifyTargetCommunityId
        let resolvedVerifyTargetCommunityName = normalizedOptional(lockContext?.verifyTargetCommunityName)
        let resolvedVerifyTargetCommunityShortName: String? = {
            guard let resolvedVerifyTargetCommunityId,
                  let postCommunityId = post.communityId,
                  resolvedVerifyTargetCommunityId == postCommunityId
            else {
                return nil
            }
            return resolvedPostCommunityShortName
        }()
        let resolvedSpecializationId = primaryUnlockAction?.specializationId ?? lockContext?.specializationId ?? post.communityId

        let fallbackVerificationReason = LockReason.communityVerificationRequired(
            communityId: resolvedVerifyTargetCommunityId ?? lockContext?.communityId ?? post.communityId,
            communityName: resolvedVerifyTargetCommunityName ?? resolvedLockCommunityName,
            fieldName: nil,
            majorName: nil,
            joinCreditsRemaining: nil,
            alreadyVerifiedElsewhere: resolvedAlreadyVerifiedElsewhere,
            communityButtonShortName: resolvedVerifyTargetCommunityShortName ?? resolvedPostCommunityShortName
        )

        if let primaryUnlockAction {
            switch primaryUnlockAction.type {
            case .verifyCommunity:
                return fallbackVerificationReason
            case .joinSpecialization:
                return .specializationJoinRequired(
                    communityId: resolvedSpecializationId ?? -1,
                    communityName: resolvedLockCommunityName,
                    fieldName: fieldNameFromContext,
                    majorName: majorNameFromContext,
                    joinCreditsRemaining: resolvedJoinCreditsRemaining,
                    alreadyVerifiedElsewhere: resolvedAlreadyVerifiedElsewhere
                )
            case .verifyParentThenJoin:
                return .joinRequiresVerificationFirst(
                    communityId: resolvedSpecializationId,
                    communityName: resolvedLockCommunityName,
                    fieldName: fieldNameFromContext,
                    majorName: majorNameFromContext,
                    joinCreditsRemaining: resolvedJoinCreditsRemaining,
                    alreadyVerifiedElsewhere: resolvedAlreadyVerifiedElsewhere,
                    requiredVerificationKind: lockContext?.requiredVerificationKind,
                    verifyTargetCommunityId: resolvedVerifyTargetCommunityId,
                    verifyTargetCommunityName: resolvedVerifyTargetCommunityName
                )
            case .none, .unknown:
                break
            }
        }

        let lockReason = viewerCapabilities?.lockReason ?? inferredFallbackLockReason
        guard let lockReason else {
            return fallbackVerificationReason
        }

        switch lockReason {
        case .communityNotVerified, .verificationExpired:
            return fallbackVerificationReason

        case .specializationNotJoined:
            if let resolvedSpecializationId, resolvedSpecializationId > 0 {
                return .specializationJoinRequired(
                    communityId: resolvedSpecializationId,
                    communityName: resolvedLockCommunityName,
                    fieldName: fieldNameFromContext,
                    majorName: majorNameFromContext,
                    joinCreditsRemaining: resolvedJoinCreditsRemaining,
                    alreadyVerifiedElsewhere: resolvedAlreadyVerifiedElsewhere
                )
            }

            let details = await fetchLockCommunityDetails()
            let resolvedName = details?.name ?? resolvedCommunityName
            let specializationType = details?.specializationType ?? .unknown
            let fieldName = specializationType == .field ? resolvedName : nil
            let majorName = specializationType == .major ? resolvedName : nil
            let joinRemaining = details?.joinLimit?.remaining
            let requiresVerification = details?.joinLimit?.requiresVerificationForJoin ?? false
            let requiredKind = details?.joinLimit?.requiredVerificationKind

            if requiresVerification {
                return .joinRequiresVerificationFirst(
                    communityId: post.communityId,
                    communityName: resolvedCommunityName,
                    fieldName: fieldName,
                    majorName: majorName,
                    joinCreditsRemaining: joinRemaining,
                    alreadyVerifiedElsewhere: false,
                    requiredVerificationKind: requiredKind,
                    verifyTargetCommunityId: nil,
                    verifyTargetCommunityName: nil
                )
            }

            return .specializationJoinRequired(
                communityId: post.communityId ?? details?.id ?? -1,
                communityName: resolvedCommunityName,
                fieldName: fieldName,
                majorName: majorName,
                joinCreditsRemaining: joinRemaining,
                alreadyVerifiedElsewhere: true
            )

        case .specializationVerificationRequired:
            return .joinRequiresVerificationFirst(
                communityId: resolvedSpecializationId ?? post.communityId,
                communityName: resolvedLockCommunityName,
                fieldName: fieldNameFromContext,
                majorName: majorNameFromContext,
                joinCreditsRemaining: resolvedJoinCreditsRemaining,
                alreadyVerifiedElsewhere: resolvedAlreadyVerifiedElsewhere,
                requiredVerificationKind: lockContext?.requiredVerificationKind,
                verifyTargetCommunityId: resolvedVerifyTargetCommunityId,
                verifyTargetCommunityName: resolvedVerifyTargetCommunityName
            )

        case .communityBanned, .unknownRestriction:
            return fallbackVerificationReason
        }
    }

    private var inferredFallbackLockReason: PostViewerLockReason? {
        if let communityPermissions {
            if communityPermissions.requiresJoin && !communityPermissions.canPost {
                return .specializationNotJoined
            }
            if communityPermissions.requiresVerification && !communityPermissions.canPost {
                return .communityNotVerified
            }
        }
        return nil
    }

    private func resolvedPostCommunityName() -> String {
        if let preferred = post.communityDisplayName(preferShortNames: preferCommunityShortNames) {
            return preferred
        }
        if let communityName = post.communityName?.trimmingCharacters(in: .whitespacesAndNewlines), !communityName.isEmpty {
            return communityName
        }
        if let kind = post.communityKind, kind != .unknown {
            return kind.rawValue.capitalized
        }
        return "this community"
    }

    private func normalizedOptional(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func fetchLockCommunityDetails() async -> CommunityProfileData? {
        guard let communityId = post.communityId, communityId > 0 else { return nil }
        if let lockCommunityDetails, lockCommunityDetails.id == communityId {
            return lockCommunityDetails
        }
        do {
            let details = try await communityService.fetchCommunityDetails(communityId: communityId)
            await MainActor.run {
                lockCommunityDetails = details
            }
            return details
        } catch {
            return nil
        }
    }

    private func presentLockedAction(reason: LockReason, actionType: LockedFeedActionType) {
        pendingLockedActionRetry = actionType
        lockedActionSheetDetent = PostCard.lockedActionDefaultDetent
        _ = LockedActionSessionTracker.shouldShowSheet(
            for: reason,
            communityId: reason.communityId ?? post.communityId
        )
        track("locked_action_sheet_shown", props: lockedActionAnalyticsProps(reason: reason, actionType: actionType))
        if let onPresentLockedActionSheet {
            let request = LockedActionSheetRequest(
                reason: reason,
                actionType: actionType,
                onPrimary: { handleLockedActionPrimary(reason: reason, actionType: actionType) },
                onSecondary: {
                    pendingLockedActionRetry = nil
                    lockedActionSheetState = nil
                },
                onHowItWorks: {
                    showLockedActionHowItWorks = true
                }
            )
            onPresentLockedActionSheet(request)
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            lockedActionToastState = nil
            lockedActionSheetState = LockedActionSheetState(reason: reason, actionType: actionType)
        }
    }

    private func showLockedActionToast(reason: LockReason, actionType: LockedFeedActionType) {
        lockedActionToastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            lockedActionToastState = LockedActionToastState(reason: reason, actionType: actionType)
        }
        lockedActionToastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                lockedActionToastState = nil
            }
        }
    }

    private func handleLockedActionPrimary(reason: LockReason, actionType: LockedFeedActionType) {
        pendingLockedActionRetry = actionType
        withAnimation(.easeInOut(duration: 0.2)) {
            lockedActionSheetState = nil
            lockedActionToastState = nil
        }
        track("locked_action_primary_tapped", props: lockedActionAnalyticsProps(reason: reason, actionType: actionType))

        switch reason {
        case .communityVerificationRequired(let communityId, _, _, _, _, _, _):
            // Verification completion should not auto-retry the original action (like/comment).
            pendingLockedActionRetry = nil
            pendingJoinAfterVerificationCommunityId = nil
            onVerifyCommunity(communityId: communityId)
        case .specializationJoinRequired(let communityId, _, _, _, _, _):
            pendingJoinAfterVerificationCommunityId = nil
            let type: CommunitySpecializationType = reason.majorName != nil ? .major : (reason.fieldName != nil ? .field : .unknown)
            onJoinSpecialization(type: type, id: communityId)
        case .joinRequiresVerificationFirst(
            let communityId,
            _,
            _,
            _,
            _,
            _,
            _,
            let verifyTargetCommunityId,
            _
        ):
            pendingJoinAfterVerificationCommunityId = communityId
            onVerifyCommunity(communityId: verifyTargetCommunityId)
        }
    }

    private func onVerifyCommunity(communityId: Int?) {
        let postId = post.backendId
        let defaultCommunityId = post.communityId
        if let trackingCommunityId = communityId ?? defaultCommunityId, trackingCommunityId > 0 {
            Task {
                await TelemetryManager.shared.trackCommunityVerifyIntent(
                    communityId: trackingCommunityId,
                    postId: postId,
                    feed: telemetryFeedContext
                )
            }
        }

        guard let communityId, communityId > 0 else {
            showVerificationCommunityPicker = true
            return
        }

        Task { @MainActor in
            let target = await verificationTarget(communityId: communityId)
            if let target {
                verificationTargetCommunity = target
            } else {
                showVerificationCommunityPicker = true
            }
        }
    }

    private func verificationTarget(communityId: Int) async -> CommunityProfileData? {
        if let lockCommunityDetails, lockCommunityDetails.id == communityId, lockCommunityDetails.kind != .specialization {
            return lockCommunityDetails
        }
        do {
            let details = try await communityService.fetchCommunityDetails(communityId: communityId)
            guard details.kind != .specialization else { return nil }
            await MainActor.run {
                lockCommunityDetails = details
            }
            return details
        } catch {
            return nil
        }
    }

	    private func onJoinSpecialization(type: CommunitySpecializationType, id: Int) {
	        guard id > 0 else {
	            actionError = PostActionError(
	                title: "Couldn't join",
                message: "This specialization is missing required data."
            )
            return
        }
        track(
            "locked_action_join_attempted",
            props: lockedActionAnalyticsProps(
                reason: .specializationJoinRequired(
                    communityId: id,
                    communityName: resolvedPostCommunityName(),
                    fieldName: type == .field ? resolvedPostCommunityName() : nil,
                    majorName: type == .major ? resolvedPostCommunityName() : nil,
                    joinCreditsRemaining: nil,
                    alreadyVerifiedElsewhere: true
                ),
                actionType: pendingLockedActionRetry ?? .like
            )
        )
        joinSpecialization(communityId: id) {
            Task { @MainActor in
                await retryPendingLockedActionIfPossible()
            }
        }
	    }

	    @MainActor
	    private func handleVerificationFlowCompleted(
	        community: CommunityProfileData,
	        completion: CommunityVerificationCompletion
	    ) async {
	        await authViewModel.loadCurrentUser()
	        await refreshCommunityPermissions()

	        switch completion {
	        case .verified:
	            let didStartJoin = await attemptJoinAfterVerificationIfPossible()
	            if didStartJoin {
	                // Join flow will handle retrying the original intent after the join completes.
	                return
	            }

	            // Verification is complete, but we intentionally do not auto-like/comment.
	            pendingLockedActionRetry = nil
	            pendingJoinAfterVerificationCommunityId = nil
	            presentToast(ToastMessage(text: "Verified in \(community.name).", kind: .success))

	        case .submitted:
	            // Photo ID / badge verifications may be reviewed async. Don't retry any locked actions.
	            pendingLockedActionRetry = nil
	            pendingJoinAfterVerificationCommunityId = nil
	            presentToast(ToastMessage(text: "Verification submitted for \(community.name).", kind: .pending))
	        }
	    }

	    @MainActor
	    private func handleVerificationFlowDismissed() async {
	        // User closed the verification flow without finishing; clear any pending intent.
	        pendingLockedActionRetry = nil
	        pendingJoinAfterVerificationCommunityId = nil
	    }

	    @MainActor
	    private func handleVerificationPickerDismissed() async {
	        // The picker can be dismissed without verifying. Don't retry any locked actions here.
	        await refreshCommunityPermissions()
	        pendingLockedActionRetry = nil
	        pendingJoinAfterVerificationCommunityId = nil
	    }

	    @MainActor
	    private func attemptJoinAfterVerificationIfPossible() async -> Bool {
	        guard let communityId = pendingJoinAfterVerificationCommunityId, communityId > 0 else { return false }
	        // Force-refresh details after verification so joinLimit reflects the updated state.
	        lockCommunityDetails = nil
	        let details = await fetchLockCommunityDetails()
	        if details?.joinLimit?.requiresVerificationForJoin == true {
	            return false
	        }
	        pendingJoinAfterVerificationCommunityId = nil
	        let action = pendingLockedActionRetry ?? .like
	        let type: CommunitySpecializationType = details?.specializationType ?? .unknown
	        onJoinSpecialization(type: type, id: communityId)
	        pendingLockedActionRetry = action
	        return true
	    }

    @MainActor
    private func retryPendingLockedActionIfPossible() async {
        guard let action = pendingLockedActionRetry else { return }
        pendingLockedActionRetry = nil
        switch action {
        case .like:
            handleLikeToggle(allowRetryBypass: true)
        case .comment:
            openCommentsIfPossible()
        case .post:
            break
        }
    }

    private func lockedActionAnalyticsProps(reason: LockReason, actionType: LockedFeedActionType) -> [String: String] {
        [
            "action_type": actionType.rawValue,
            "reason_type": reason.sessionPresentationTypeKey,
            "community_id": String(reason.communityId ?? post.communityId ?? -1),
            "community_name": reason.communityName
        ]
    }

    private func track(_ event: String, props: [String: String]) {
        _ = (event, props)
        // Analytics hook stub. Wire this into the shared analytics pipeline.
    }

    private var joinPrimaryAction: PostActionError.PrimaryAction? {
        if viewerCapabilities?.lockReason == .specializationNotJoined,
           let communityId = post.communityId,
           communityId > 0 {
            return .joinSpecialization(communityId: communityId)
        }
        guard let communityPermissions else { return nil }
        guard communityPermissions.requiresJoin && !communityPermissions.canPost else { return nil }
        guard let communityId = post.communityId, communityId > 0 else { return nil }
        return .joinSpecialization(communityId: communityId)
    }

    private func handlePrimaryAction(_ action: PostActionError.PrimaryAction) {
        switch action {
        case .joinSpecialization(let communityId):
            joinSpecialization(communityId: communityId)
        }
    }

    private func openCommentsIfPossible() {
        guard post.backendId != nil else {
            presentMissingPostIdError(action: "open comments")
            return
        }
        commentsManager.showComments(
            for: post,
            telemetryFeedContext: telemetryFeedContext,
            telemetryEntryPoint: telemetryEntryPoint
        )
    }

    private func presentMissingPostIdError(action: String) {
        actionError = PostActionError(
            title: "Post unavailable",
            message: "This post is missing required data, so we can't \(action) right now. Pull to refresh and try again."
        )
    }

    private func presentMissingAuthorProfileError() {
        actionError = PostActionError(
            title: "Profile unavailable",
            message: "This post is missing author profile data. Pull to refresh and try again."
        )
    }

    private func joinSpecialization(communityId: Int, onSuccess: (() -> Void)? = nil) {
        guard communityId > 0 else { return }
        guard !isJoiningSpecialization else { return }
        let postId = post.backendId
        Task {
            await TelemetryManager.shared.trackCommunityJoinIntent(
                communityId: communityId,
                postId: postId,
                feed: telemetryFeedContext
            )
        }
        isJoiningSpecialization = true
        Task {
            defer { isJoiningSpecialization = false }
            do {
                let service = CommunityService()
                try await service.joinSpecialization(id: communityId)
                await CommunityPermissionsCache.shared.invalidate(communityId: communityId)
                communityPermissions = await CommunityPermissionsCache.shared.permissions(communityId: communityId)
                await feedViewModel.loadFollowedCommunities(reset: true)
                onSuccess?()
            } catch {
                actionError = PostActionError(
                    title: "Couldn't join",
                    message: joinErrorMessage(from: error)
                )
            }
        }
    }

    private func joinErrorMessage(from error: Error) -> String {
        if case let APIError.apiError(_, apiError, message) = error {
            switch apiError {
            case "specialization_verification_required":
                return message ?? "Verification is required to join."
            case "specialization_join_limit":
                return message ?? "You’ve reached the join limit."
            case "specialization_join_cooldown":
                return message ?? "You can’t change this right now."
            case "invalid_specialization":
                return message ?? "That specialization can't be joined."
            default:
                return message ?? apiError
            }
        }
        return error.localizedDescription
    }

    private func syncViewerAnonProfileId() async {
        viewerAnonProfileId = await AnonService.shared.currentIdentity()?.profileId
    }

    private var isUnderReviewVisibleToViewer: Bool {
        guard post.isUnderReview else { return false }
        if post.isAnonymous {
            guard let viewerAnonProfileId else { return false }
            return post.anonProfileId == viewerAnonProfileId
        }
        guard let viewerUserId = authViewModel.currentUser?.backendId else { return false }
        return post.authorBackendId == viewerUserId
    }

    @ViewBuilder
    private var underReviewBanner: some View {
        if isUnderReviewVisibleToViewer {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.loopedCustom(.medium, size: 14))
                    .foregroundColor(.loopedTextSecondary)

                Text("Under review")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.loopedMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.loopedTextSecondary.opacity(0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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

private struct PostActionError: Identifiable {
    enum PrimaryAction {
        case joinSpecialization(communityId: Int)
    }

    let id = UUID()
    let title: String
    let message: String
    let primaryAction: PrimaryAction?

    init(title: String, message: String, primaryAction: PrimaryAction? = nil) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
    }
}

private struct LockedActionSheetState: Identifiable {
    let id = UUID()
    let reason: LockReason
    let actionType: LockedFeedActionType
}

private struct LockedActionToastState: Equatable {
    let reason: LockReason
    let actionType: LockedFeedActionType
}

private extension PostCard {
    var isOwnedByActiveActor: Bool {
        post.isOwnedByActiveActor(
            currentUserId: authViewModel.currentUser?.backendId,
            currentAnonProfileId: viewerAnonProfileId,
            isAnonymousMode: isAnonymousMode
        )
    }

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
        guard post.backendId != nil else { return false }
        return !isOwnedByActiveActor
    }

    var canReportUser: Bool {
        guard !isOwnedByActiveActor else { return false }
        guard let authorId = post.authorBackendId else { return false }
        if let currentUser = authViewModel.currentUser, currentUser.backendId == authorId {
            return false
        }
        return true
    }

    var canDeletePost: Bool {
        guard post.backendId != nil else { return false }
        return isOwnedByActiveActor
    }

    var canEditPost: Bool {
        canDeletePost
    }

    var canBlockUser: Bool {
        guard !isOwnedByActiveActor else { return false }
        if let authorId = post.authorBackendId {
            if let currentUser = authViewModel.currentUser, currentUser.backendId == authorId {
                return false
            }
            return true
        }
        return post.authorPrincipalId != nil
    }

    var canAppealPostRemoval: Bool {
        guard showsAppealPostRemoval else { return false }
        guard let currentUser = authViewModel.currentUser else { return false }
        return post.backendId != nil && post.authorBackendId == currentUser.backendId
    }
}

struct EditPostSheet: View {
    @Binding var text: String
    @Binding var removeMedia: Bool
    let hasMedia: Bool
    let hasPoll: Bool
    let communityLabel: String
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    private let characterLimit = 500

    private var remainingCharacters: Int {
        characterLimit - text.count
    }

    private var isValid: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && text.count <= characterLimit
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .font(.loopedCustom(size: 13))
                            .foregroundColor(.loopedTextSecondary)

                        Text("Posted in \(communityLabel)")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    if hasPoll {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.loopedCustom(size: 14))
                                .foregroundColor(.loopedTextSecondary)

                            Text("This post has a poll. Poll options can't be edited here.")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.loopedMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if hasMedia {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Remove attached media", isOn: $removeMedia)
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                                .toggleStyle(SwitchToggleStyle(tint: .loopedPrimary))
                                .disabled(isSaving)

                            Text(removeMedia ? "Media will be removed when you save." : "Adding or replacing media isn't supported when editing.")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.loopedMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("What's happening?")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextSecondary)

                            Spacer()

                            Text("\(remainingCharacters) characters left")
                                .font(.loopedSmallText)
                                .foregroundColor(remainingCharacters < 20 ? .loopedError : .loopedTextSecondary)
                        }

                        TextField("Share your thoughts...", text: $text, axis: .vertical)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .lineLimit(6...10)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LoopedCancelTextButton(action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { onSave() }
                        .disabled(!isValid || isSaving)
                        .foregroundColor((isValid && !isSaving) ? .loopedPrimary : .loopedTextSecondary)
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType] = []
    var onComplete: ((Bool, UIActivity.ActivityType?) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            onComplete?(completed, activityType)
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
        .environmentObject(FeedViewModel())
}
