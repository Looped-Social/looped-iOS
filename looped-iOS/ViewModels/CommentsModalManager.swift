import SwiftUI
import Combine
import UIKit

@MainActor
class CommentsModalManager: ObservableObject {
    @Published var isPresented = false
    @Published var currentPost: Post?
    @Published var currentComments: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isPosting = false
    @Published var isLoadingPermissions = false
    @Published var errorMessage: String?
    @Published var toastMessage: ToastMessage?
    @Published var replyThreads: [Int: ReplyThreadState] = [:]
    @Published var replyTarget: Comment?
    @Published var editTarget: Comment?
    @Published var communityPermissions: CommunityPermissions?
    @Published var focusCommentId: Int?
    @Published var focusParentId: Int?
    
    private let commentsService: CommentsServiceProtocol
    private let communityService: CommunityServiceProtocol
    private let mediaService: MediaServiceProtocol
    private var nextCursor: String?
    private var currentPostBackendId: Int?
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    init(
        commentsService: CommentsServiceProtocol = CommentsService(),
        communityService: CommunityServiceProtocol = CommunityService(),
        mediaService: MediaServiceProtocol = MediaService()
    ) {
        self.commentsService = commentsService
        self.communityService = communityService
        self.mediaService = mediaService
        NotificationCenter.default.publisher(for: .communityStateChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshCommunityPermissions() }
            }
            .store(in: &cancellables)
    }
    
    func showComments(
        for post: Post,
        focusCommentId: Int? = nil,
        focusParentId: Int? = nil,
        telemetryFeedContext: TelemetryFeedContext? = nil,
        telemetryEntryPoint: String? = nil
    ) {
        guard let backendId = post.backendId else { return }
        Task {
            await TelemetryManager.shared.trackPostOpen(
                postId: backendId,
                feed: telemetryFeedContext,
                entryPoint: telemetryEntryPoint
            )
            await TelemetryManager.shared.trackCommentsOpen(
                postId: backendId,
                feed: telemetryFeedContext
            )
        }
        currentPost = post
        currentPostBackendId = backendId
        currentComments = []
        nextCursor = nil
        errorMessage = nil
        toastMessage = nil
        replyThreads = [:]
        replyTarget = nil
        editTarget = nil
        isLoadingPermissions = false
        communityPermissions = nil
        self.focusCommentId = focusCommentId
        self.focusParentId = focusParentId
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPresented = true
        }
        Task { await loadComments(reset: true) }
        Task { await loadPermissions() }
    }

    func dismissComments() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isPresented = false
        }
        // Delay clearing the data to allow for smooth animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.currentPost = nil
            self.currentComments = []
            self.currentPostBackendId = nil
            self.nextCursor = nil
            self.errorMessage = nil
            self.toastMessage = nil
            self.replyThreads = [:]
            self.replyTarget = nil
            self.editTarget = nil
            self.isLoadingPermissions = false
            self.communityPermissions = nil
            self.focusCommentId = nil
            self.focusParentId = nil
        }
    }

    func loadMoreIfNeeded(current comment: Comment) async {
        guard let last = currentComments.last, last.id == comment.id else { return }
        await loadComments(reset: false)
    }

    private func loadReplies(for comment: Comment, reset: Bool, preserveExistingReplies: Bool = false) async {
        guard let commentId = comment.backendId else { return }
        var state = replyThreads[commentId] ?? ReplyThreadState()

        if reset {
            state.isLoading = true
            state.isLoadingMore = false
            state.nextCursor = nil
            if !preserveExistingReplies {
                state.replies = []
            }
        } else {
            guard state.nextCursor != nil, !state.isLoadingMore else { return }
            state.isLoadingMore = true
        }
        replyThreads[commentId] = state

        do {
            let page = try await commentsService.fetchReplies(
                commentId: commentId,
                communityId: currentPost?.communityId,
                limit: pageSize,
                cursor: reset ? nil : state.nextCursor
            )
            let visibleReplies = page.comments.filter { !$0.isDeleted || effectiveThreadReplyCount(for: $0) > 0 }
            var updated = replyThreads[commentId] ?? ReplyThreadState()
            if reset {
                if preserveExistingReplies {
                    updated.replies = Self.deduplicatedCommentsForDisplay(visibleReplies + updated.replies)
                } else {
                    updated.replies = visibleReplies
                }
            } else {
                updated.replies.append(contentsOf: visibleReplies)
                updated.replies = Self.deduplicatedCommentsForDisplay(updated.replies)
            }
            updated.nextCursor = page.nextCursor
            updated.isExpanded = true
            updated.isLoading = false
            updated.isLoadingMore = false
            updated.hasLoadedFromEndpoint = true
            replyThreads[commentId] = updated
        } catch {
            var updated = replyThreads[commentId] ?? ReplyThreadState()
            updated.isExpanded = state.isExpanded
            updated.isLoading = false
            updated.isLoadingMore = false
            replyThreads[commentId] = updated
            if isNotFound(error) {
                toastMessage = ToastMessage(text: "Content unavailable", kind: .info)
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func threadState(for comment: Comment) -> ReplyThreadState {
        guard let backendId = comment.backendId else {
            return ReplyThreadState()
        }
        return replyThreads[backendId] ?? ReplyThreadState()
    }

    func toggleReplies(for comment: Comment) async {
        guard let backendId = comment.backendId else { return }
        var state = replyThreads[backendId] ?? ReplyThreadState()
        if state.isExpanded {
            state.isExpanded = false
            replyThreads[backendId] = state
            return
        }
        state.isExpanded = true
        replyThreads[backendId] = state

        // Inline-seeded replies from the post comments payload can be partial.
        // Always do one authoritative endpoint fetch on first expansion.
        let threadReplyCount = effectiveThreadReplyCount(for: comment)
        if threadReplyCount > 0 && !state.hasLoadedFromEndpoint {
            await loadReplies(
                for: comment,
                reset: true,
                preserveExistingReplies: !state.replies.isEmpty
            )
            return
        }

        if state.replies.isEmpty && threadReplyCount > 0 {
            await loadReplies(for: comment, reset: true)
        }
    }

    func loadMoreRepliesIfNeeded(for comment: Comment) async {
        guard let backendId = comment.backendId else { return }
        let state = replyThreads[backendId] ?? ReplyThreadState()
        guard state.isExpanded, state.nextCursor != nil, !state.isLoadingMore else { return }
        await loadReplies(for: comment, reset: false)
    }

    func setReplyTarget(_ comment: Comment) {
        replyTarget = comment
        editTarget = nil
    }

    func clearReplyTarget() {
        replyTarget = nil
    }

    func setEditTarget(_ comment: Comment) {
        editTarget = comment
        replyTarget = nil
    }

    func clearEditTarget() {
        editTarget = nil
    }

    func postComment(content: String, media: [LocalMediaItem]) async {
        guard let postId = currentPostBackendId else { return }
        if !AnonService.shared.isAnonymousEnabled {
            if let capabilities = currentPost?.viewerCapabilities {
                if replyTarget != nil {
                    guard capabilities.canInteract && capabilities.canReply else {
                        trackBlockedInteraction(action: .reply, capabilities: capabilities)
                        errorMessage = lockMessage(from: capabilities, verb: "reply")
                        return
                    }
                } else {
                    guard capabilities.canInteract && capabilities.canComment else {
                        trackBlockedInteraction(action: .comment, capabilities: capabilities)
                        errorMessage = lockMessage(from: capabilities, verb: "comment")
                        return
                    }
                }
            } else if let permissions = communityPermissions, !permissions.canPost {
                let action: TelemetryInteractionAction = replyTarget != nil ? .reply : .comment
                trackBlockedInteraction(action: action, permissions: permissions)
                if permissions.requiresJoin {
                    errorMessage = "Join this major or field to comment or like."
                } else if permissions.requiresVerification {
                    errorMessage = "Verification is required to comment or like in this community."
                } else {
                    errorMessage = "You can’t comment in this community right now."
                }
                return
            }
        }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty || !media.isEmpty else { return }
        guard !isPosting else { return }
        isPosting = true
        defer { isPosting = false }

        do {
            let parentId = replyTarget?.backendId
            var mediaAssetId: Int?
            var uploadedAttachment: MediaAttachment?
            if let first = media.first {
                let actor: MediaUploadActor = AnonService.shared.isAnonymousEnabled ? .anon : .user
                let uploaded = try await upload(first, actor: actor)
                mediaAssetId = uploaded.asset.id
                uploadedAttachment = uploaded.attachment
            }
            let comment = try await commentsService.createComment(
                postId: postId,
                communityId: currentPost?.communityId,
                content: trimmedContent,
                parentId: parentId,
                mediaAssetId: mediaAssetId
            )
            let resolvedComment: Comment
            if let uploadedAttachment, (comment.attachments?.isEmpty ?? true) {
                resolvedComment = comment.updating(attachments: .some([uploadedAttachment]))
            } else {
                resolvedComment = comment
            }
            if let parentId = parentId {
                var state = replyThreads[parentId] ?? ReplyThreadState(isExpanded: true)
                state.replies.append(resolvedComment)
                replyThreads[parentId] = state
                if let index = currentComments.firstIndex(where: { $0.backendId == parentId }) {
                    let parent = currentComments[index]
                    let updatedReplyCount = parent.replyCount + 1
                    let updatedTotalReplyCount: Int?? = parent.totalReplyCount == nil
                        ? nil
                        : .some((parent.totalReplyCount ?? parent.replyCount) + 1)
                    currentComments[index] = parent.updating(
                        replyCount: updatedReplyCount,
                        totalReplyCount: updatedTotalReplyCount
                    )
                }
            } else {
                currentComments.append(resolvedComment)
            }
            if let post = currentPost {
                currentPost = post.updating(commentsCount: post.commentsCount + 1)
            }
            replyTarget = nil
            LoopedHaptics.success()
        } catch {
            if isContentUnderReview(error), AnonService.shared.isAnonymousEnabled {
                toastMessage = ToastMessage(text: "Under review", kind: .info)
                replyTarget = nil
                errorMessage = nil
                return
            }
            if isNotFound(error) {
                toastMessage = ToastMessage(text: "Content unavailable", kind: .info)
                errorMessage = nil
                return
            }
            if case let APIError.apiError(_, apiError, message) = error {
                switch apiError {
                case "community_not_verified":
                    errorMessage = message ?? "You must be verified in this community to comment. Go to a community and tap Verify."
                case "specialization_not_joined":
                    errorMessage = message ?? "Join this major or field to comment."
                default:
                    errorMessage = message ?? apiError
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func editComment(content: String) async {
        guard let target = editTarget, let commentId = target.backendId else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isPosting else { return }
        isPosting = true
        defer { isPosting = false }

        do {
            let updated = try await commentsService.editComment(
                commentId: commentId,
                communityId: currentPost?.communityId,
                content: trimmed,
                asAnon: target.isAnonymous
            )
            if let index = currentComments.firstIndex(where: { $0.backendId == updated.backendId }) {
                currentComments[index] = updated
            }
            if let parentKey = replyThreads.first(where: { $0.value.replies.contains(where: { $0.backendId == updated.backendId }) })?.key,
               var state = replyThreads[parentKey],
               let replyIndex = state.replies.firstIndex(where: { $0.backendId == updated.backendId }) {
                state.replies[replyIndex] = updated
                replyThreads[parentKey] = state
            }
            editTarget = nil
        } catch {
            if isContentUnderReview(error), target.isAnonymous, AnonService.shared.isAnonymousEnabled {
                toastMessage = ToastMessage(text: "Under review", kind: .info)
                editTarget = nil
                errorMessage = nil
                return
            }
            if isNotFound(error) {
                toastMessage = ToastMessage(text: "Content unavailable", kind: .info)
                editTarget = nil
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func deleteComment(_ comment: Comment) async {
        guard let commentId = comment.backendId, !comment.isDeleted else { return }
        do {
            let response = try await commentsService.deleteComment(
                commentId: commentId,
                communityId: currentPost?.communityId,
                asAnon: comment.isAnonymous
            )
            guard response.deleted else { return }
            if let index = currentComments.firstIndex(where: { $0.backendId == commentId }) {
                let existing = currentComments[index]
                let loadedReplyCount = replyThreads[commentId]?.replies.count ?? 0
                let effectiveReplyCount = max(effectiveThreadReplyCount(for: existing), loadedReplyCount)
                if effectiveReplyCount == 0 {
                    currentComments.remove(at: index)
                    replyThreads[commentId] = nil
                } else {
                    currentComments[index] = existing.updating(content: "", isDeleted: true)
                }
            }
            if let parentKey = replyThreads.first(where: { $0.value.replies.contains(where: { $0.backendId == commentId }) })?.key,
               var state = replyThreads[parentKey],
               let replyIndex = state.replies.firstIndex(where: { $0.backendId == commentId }) {
                let existingReply = state.replies[replyIndex]
                let nestedReplyCount = existingReply.backendId.flatMap { replyThreads[$0]?.replies.count } ?? 0
                let effectiveReplyCount = max(effectiveThreadReplyCount(for: existingReply), nestedReplyCount)
                if effectiveReplyCount == 0 {
                    state.replies.remove(at: replyIndex)
                    if let parentIndex = currentComments.firstIndex(where: { $0.backendId == parentKey }) {
                        let parent = currentComments[parentIndex]
                        let updatedReplyCount = max(parent.replyCount - 1, 0)
                        let updatedTotalReplyCount: Int?? = parent.totalReplyCount == nil
                            ? nil
                            : .some(max((parent.totalReplyCount ?? parent.replyCount) - 1, 0))
                        currentComments[parentIndex] = parent.updating(
                            replyCount: updatedReplyCount,
                            totalReplyCount: updatedTotalReplyCount
                        )
                    }
                } else {
                    state.replies[replyIndex] = existingReply.updating(content: "", isDeleted: true)
                }
                replyThreads[parentKey] = state
            }
            if editTarget?.backendId == commentId {
                editTarget = nil
            }
            if replyTarget?.backendId == commentId {
                replyTarget = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(for comment: Comment) async {
        guard let backendId = comment.backendId else { return }
        if !AnonService.shared.isAnonymousEnabled,
           let capabilities = currentPost?.viewerCapabilities,
           (!capabilities.canInteract || !capabilities.canLike) {
            errorMessage = lockMessage(from: capabilities, verb: "like comments")
            return
        }
        do {
            let response: CommentLikeResponse
            if comment.userLiked {
                response = try await commentsService.unlikeComment(
                    commentId: backendId,
                    communityId: currentPost?.communityId
                )
            } else {
                response = try await commentsService.likeComment(
                    commentId: backendId,
                    communityId: currentPost?.communityId
                )
            }
            if let index = currentComments.firstIndex(where: { $0.backendId == response.commentId }) {
                currentComments[index] = currentComments[index].updating(
                    likeCount: response.likesCount,
                    userLiked: response.userLiked,
                    isLikedByCreator: response.likedByCreator
                )
            }
            if let parentKey = replyThreads.first(where: { $0.value.replies.contains(where: { $0.backendId == response.commentId }) })?.key,
               var state = replyThreads[parentKey],
               let threadIndex = state.replies.firstIndex(where: { $0.backendId == response.commentId }) {
                state.replies[threadIndex] = state.replies[threadIndex].updating(
                    likeCount: response.likesCount,
                    userLiked: response.userLiked,
                    isLikedByCreator: response.likedByCreator
                )
                replyThreads[parentKey] = state
            }
            if !comment.userLiked {
                LoopedHaptics.success()
            }
        } catch {
            if isNotFound(error) {
                toastMessage = ToastMessage(text: "Content unavailable", kind: .info)
                errorMessage = nil
                return
            }
            if case let APIError.apiError(_, apiError, message) = error {
                switch apiError {
                case "community_not_verified":
                    errorMessage = message ?? "You must be verified in this community to like comments. Go to a community and tap Verify."
                case "specialization_not_joined":
                    errorMessage = message ?? "Join this major or field to like comments."
                default:
                    errorMessage = message ?? apiError
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadComments(reset: Bool) async {
        guard let postId = currentPostBackendId else { return }
        if reset {
            isLoading = true
            nextCursor = nil
            currentComments = []
        } else {
            guard !isLoadingMore, nextCursor != nil else { return }
            isLoadingMore = true
        }
        defer {
            if reset {
                isLoading = false
            } else {
                isLoadingMore = false
            }
        }

        do {
            let page = try await commentsService.fetchComments(
                postId: postId,
                communityId: currentPost?.communityId,
                limit: pageSize,
                cursor: reset ? nil : nextCursor
            )
            let normalized = Self.partitionCommentsForDisplay(page.comments)
            if reset {
                currentComments = normalized.topLevelComments
            } else {
                currentComments = mergeDeduplicatedComments(
                    existing: currentComments,
                    incoming: normalized.topLevelComments
                )
            }
            if !normalized.inlineRepliesByParentId.isEmpty {
                mergeInlineReplies(normalized.inlineRepliesByParentId)
            }
            nextCursor = page.nextCursor
            if let parentId = focusParentId,
               let parent = currentComments.first(where: { $0.backendId == parentId }) {
                await loadReplies(for: parent, reset: true)
            }
        } catch {
            if isNotFound(error) {
                errorMessage = "Content unavailable"
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    static func partitionCommentsForDisplay(_ comments: [Comment]) -> (topLevelComments: [Comment], inlineRepliesByParentId: [Int: [Comment]]) {
        var topLevelComments: [Comment] = []
        var inlineRepliesByParentId: [Int: [Comment]] = [:]

        for comment in comments {
            if let parentId = comment.replyToBackendId {
                inlineRepliesByParentId[parentId, default: []].append(comment)
            } else {
                topLevelComments.append(comment)
            }
        }

        let dedupedTopLevel = deduplicatedCommentsForDisplay(topLevelComments).filter { comment in
            let hasThreadReplies = max(comment.totalReplyCount ?? comment.replyCount, 0) > 0
            guard comment.isDeleted, !hasThreadReplies else { return true }
            guard let backendId = comment.backendId else { return true }
            let inlineReplyCount = inlineRepliesByParentId[backendId]?.count ?? 0
            return inlineReplyCount > 0
        }
        let dedupedReplies = inlineRepliesByParentId.mapValues { deduplicatedCommentsForDisplay($0) }
        return (dedupedTopLevel, dedupedReplies)
    }

    private func mergeInlineReplies(_ inlineRepliesByParentId: [Int: [Comment]]) {
        guard !inlineRepliesByParentId.isEmpty else { return }

        for (parentId, inlineReplies) in inlineRepliesByParentId {
            var state = replyThreads[parentId] ?? ReplyThreadState()
            state.replies = mergeDeduplicatedComments(existing: state.replies, incoming: inlineReplies)
            replyThreads[parentId] = state
        }
    }

    private func mergeDeduplicatedComments(existing: [Comment], incoming: [Comment]) -> [Comment] {
        Self.deduplicatedCommentsForDisplay(existing + incoming)
    }

    static func deduplicatedCommentsForDisplay(_ comments: [Comment]) -> [Comment] {
        var seenBackendIds = Set<Int>()
        var seenLocalIds = Set<UUID>()
        var unique: [Comment] = []

        for comment in comments {
            if let backendId = comment.backendId {
                guard seenBackendIds.insert(backendId).inserted else { continue }
                unique.append(comment)
                continue
            }

            guard seenLocalIds.insert(comment.id).inserted else { continue }
            unique.append(comment)
        }

        return unique
    }

    private func effectiveThreadReplyCount(for comment: Comment) -> Int {
        max(comment.totalReplyCount ?? comment.replyCount, 0)
    }

    private func loadPermissions() async {
        guard !AnonService.shared.isAnonymousEnabled else {
            communityPermissions = nil
            return
        }
        guard currentPost?.viewerCapabilities == nil else {
            communityPermissions = nil
            return
        }
        guard let communityId = currentPost?.communityId, communityId > 0 else {
            communityPermissions = nil
            return
        }
        guard !isLoadingPermissions else { return }
        isLoadingPermissions = true
        defer { isLoadingPermissions = false }
        do {
            communityPermissions = try await communityService.fetchCommunityPermissions(communityId: communityId)
        } catch {
            communityPermissions = nil
        }
    }

    func refreshCommunityPermissions() async {
        await loadPermissions()
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

    private func lockMessage(from capabilities: PostViewerCapabilities, verb: String) -> String {
        if capabilities.lockReason == .specializationNotJoined {
            return "Join this major or field to \(verb)."
        }
        return capabilities.lockMessage(for: verb)
    }

    private func trackBlockedInteraction(
        action: TelemetryInteractionAction,
        capabilities: PostViewerCapabilities
    ) {
        let lockReason = capabilities.lockReason?.rawValue ?? PostViewerLockReason.unknownRestriction.rawValue
        trackBlockedInteraction(action: action, lockReason: lockReason)
    }

    private func trackBlockedInteraction(
        action: TelemetryInteractionAction,
        permissions: CommunityPermissions
    ) {
        let lockReason: String
        if permissions.requiresJoin {
            lockReason = PostViewerLockReason.specializationNotJoined.rawValue
        } else if permissions.requiresVerification {
            lockReason = PostViewerLockReason.communityNotVerified.rawValue
        } else {
            lockReason = PostViewerLockReason.unknownRestriction.rawValue
        }
        trackBlockedInteraction(action: action, lockReason: lockReason)
    }

    private func trackBlockedInteraction(action: TelemetryInteractionAction, lockReason: String) {
        guard let postId = currentPostBackendId else { return }
        Task {
            await TelemetryManager.shared.trackInteractionBlocked(
                postId: postId,
                feed: nil,
                action: action,
                lockReason: lockReason
            )
        }
    }
}

struct ReplyThreadState {
    var replies: [Comment] = []
    var nextCursor: String? = nil
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var isExpanded: Bool = false
    var hasLoadedFromEndpoint: Bool = false

    init(
        replies: [Comment] = [],
        nextCursor: String? = nil,
        isLoading: Bool = false,
        isLoadingMore: Bool = false,
        isExpanded: Bool = false,
        hasLoadedFromEndpoint: Bool = false
    ) {
        self.replies = replies
        self.nextCursor = nextCursor
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.isExpanded = isExpanded
        self.hasLoadedFromEndpoint = hasLoadedFromEndpoint
    }
}

private extension CommentsModalManager {
    struct UploadResult {
        let asset: MediaAsset
        let attachment: MediaAttachment?
    }

    func upload(_ item: LocalMediaItem, actor: MediaUploadActor) async throws -> UploadResult {
        switch item.type {
        case .image:
            guard let image = item.image else { throw CommentMediaUploadError.unreadable }
            guard let payload = makeUploadPayload(from: image) else { throw CommentMediaUploadError.unreadable }
            let asset = try await mediaService.uploadImage(
                data: payload.data,
                mimeType: payload.mimeType,
                width: payload.width,
                height: payload.height,
                actor: actor
            )
            let attachment = asset.cdnUrl.flatMap { url -> MediaAttachment? in
                guard !url.isEmpty else { return nil }
                return MediaAttachment(id: "asset:\(asset.id)", type: .image, url: url, width: payload.width, height: payload.height)
            }
            return UploadResult(asset: asset, attachment: attachment)
        case .video:
            guard let url = item.videoURL else { throw CommentMediaUploadError.unreadable }
            let mp4Url = try await VideoTranscoder.ensureMP4(at: url)
            defer {
                TemporaryMediaFile.deleteIfOwned(mp4Url)
                TemporaryMediaFile.deleteIfOwned(url)
            }
            let metadata = await videoMetadata(url: mp4Url)
            var thumbnailMediaAssetId: Int?
            var thumbnailUrl: String?
            let resolvedThumbnailImage: UIImage?
            if let existing = item.image {
                resolvedThumbnailImage = existing
            } else {
                resolvedThumbnailImage = await makeVideoThumbnail(url: mp4Url)
            }
            if let resolvedThumbnailImage,
               let payload = makeUploadPayload(from: resolvedThumbnailImage) {
                do {
                    let thumbnailAsset = try await mediaService.uploadImage(
                        data: payload.data,
                        mimeType: payload.mimeType,
                        width: payload.width,
                        height: payload.height,
                        actor: actor
                    )
                    thumbnailMediaAssetId = thumbnailAsset.id
                    thumbnailUrl = thumbnailAsset.cdnUrl
                } catch {
                    thumbnailMediaAssetId = nil
                    thumbnailUrl = nil
                }
            }
            let asset = try await mediaService.uploadVideo(
                fileURL: mp4Url,
                mimeType: "video/mp4",
                width: metadata.width,
                height: metadata.height,
                durationSeconds: metadata.durationSeconds,
                actor: actor,
                thumbnailMediaAssetId: thumbnailMediaAssetId
            )
            let attachment = asset.cdnUrl.flatMap { url -> MediaAttachment? in
                guard !url.isEmpty else { return nil }
                return MediaAttachment(
                    id: "asset:\(asset.id)",
                    type: .video,
                    url: url,
                    thumbnailUrl: thumbnailUrl,
                    width: metadata.width,
                    height: metadata.height,
                    duration: TimeInterval(metadata.durationSeconds)
                )
            }
            return UploadResult(asset: asset, attachment: attachment)
        case .gif:
            throw CommentMediaUploadError.unsupported
        }
    }

    func makeUploadPayload(from image: UIImage) -> ImageUploadPayload? {
        guard let output = ImageUploadTranscoder.makeUploadPayload(from: image) else { return nil }
        return ImageUploadPayload(data: output.data, mimeType: output.mimeType, width: output.width, height: output.height)
    }

    func videoMetadata(url: URL) async -> (width: Int, height: Int, durationSeconds: Int) {
        await VideoAssetUtilities.basicMetadata(for: url)
    }

    func makeVideoThumbnail(url: URL) async -> UIImage? {
        await VideoAssetUtilities.thumbnail(for: url)
    }
}

private struct ImageUploadPayload {
    let data: Data
    let mimeType: String
    let width: Int
    let height: Int
}

private enum CommentMediaUploadError: LocalizedError {
    case unsupported
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "That media type isn't supported in comments yet."
        case .unreadable:
            return "We couldn't read that attachment. Try another one."
        }
    }
}
