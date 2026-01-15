import SwiftUI
import Combine
import UIKit
import AVFoundation

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
    
    init(
        commentsService: CommentsServiceProtocol = CommentsService(),
        communityService: CommunityServiceProtocol = CommunityService(),
        mediaService: MediaServiceProtocol = MediaService()
    ) {
        self.commentsService = commentsService
        self.communityService = communityService
        self.mediaService = mediaService
    }
    
    func showComments(for post: Post, focusCommentId: Int? = nil, focusParentId: Int? = nil) {
        guard let backendId = post.backendId else { return }
        currentPost = post
        currentPostBackendId = backendId
        currentComments = []
        nextCursor = nil
        errorMessage = nil
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

    private func loadReplies(for comment: Comment, reset: Bool) async {
        guard let commentId = comment.backendId else { return }
        var state = replyThreads[commentId] ?? ReplyThreadState()

        if reset {
            state.isLoading = true
            state.isLoadingMore = false
            state.nextCursor = nil
            state.replies = []
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
            var updated = replyThreads[commentId] ?? ReplyThreadState()
            if reset {
                updated.replies = page.comments
            } else {
                updated.replies.append(contentsOf: page.comments)
            }
            updated.nextCursor = page.nextCursor
            updated.isExpanded = true
            updated.isLoading = false
            updated.isLoadingMore = false
            replyThreads[commentId] = updated
        } catch {
            var updated = replyThreads[commentId] ?? ReplyThreadState()
            updated.isExpanded = state.isExpanded
            updated.isLoading = false
            updated.isLoadingMore = false
            replyThreads[commentId] = updated
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
        guard !state.isExpanded else { return }
        state.isExpanded = true
        replyThreads[backendId] = state

        if state.replies.isEmpty {
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
        if let permissions = communityPermissions, !permissions.canPost {
            errorMessage = "Verification is required to comment in this community."
            return
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
                    currentComments[index] = currentComments[index].updating(
                        replyCount: currentComments[index].replyCount + 1
                    )
                }
            } else {
                currentComments.append(resolvedComment)
            }
            if let post = currentPost {
                currentPost = post.updating(commentsCount: post.commentsCount + 1)
            }
            replyTarget = nil
        } catch {
            errorMessage = error.localizedDescription
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
                currentComments[index] = currentComments[index].updating(content: "", isDeleted: true)
            }
            if let parentKey = replyThreads.first(where: { $0.value.replies.contains(where: { $0.backendId == commentId }) })?.key,
               var state = replyThreads[parentKey],
               let replyIndex = state.replies.firstIndex(where: { $0.backendId == commentId }) {
                state.replies[replyIndex] = state.replies[replyIndex].updating(content: "", isDeleted: true)
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
        } catch {
            errorMessage = error.localizedDescription
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
            if reset {
                currentComments = page.comments
            } else {
                currentComments.append(contentsOf: page.comments)
            }
            nextCursor = page.nextCursor
            if let parentId = focusParentId,
               let parent = currentComments.first(where: { $0.backendId == parentId }) {
                await loadReplies(for: parent, reset: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPermissions() async {
        guard let communityId = currentPost?.communityId else {
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
}

struct ReplyThreadState {
    var replies: [Comment] = []
    var nextCursor: String? = nil
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var isExpanded: Bool = false

    init(replies: [Comment] = [], nextCursor: String? = nil, isLoading: Bool = false, isLoadingMore: Bool = false, isExpanded: Bool = false) {
        self.replies = replies
        self.nextCursor = nextCursor
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.isExpanded = isExpanded
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
            let metadata = videoMetadata(url: mp4Url)
            let asset = try await mediaService.uploadVideo(
                fileURL: mp4Url,
                mimeType: "video/mp4",
                width: metadata.width,
                height: metadata.height,
                durationSeconds: metadata.durationSeconds,
                actor: actor
            )
            let attachment = asset.cdnUrl.flatMap { url -> MediaAttachment? in
                guard !url.isEmpty else { return nil }
                return MediaAttachment(id: "asset:\(asset.id)", type: .video, url: url, width: metadata.width, height: metadata.height, duration: TimeInterval(metadata.durationSeconds))
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

    func videoMetadata(url: URL) -> (width: Int, height: Int, durationSeconds: Int) {
        let asset = AVAsset(url: url)
        let duration = Int((asset.duration.seconds.isFinite ? asset.duration.seconds : 0).rounded())
        guard let track = asset.tracks(withMediaType: .video).first else {
            return (width: 0, height: 0, durationSeconds: max(duration, 0))
        }
        let transformed = track.naturalSize.applying(track.preferredTransform)
        let width = Int(abs(transformed.width).rounded())
        let height = Int(abs(transformed.height).rounded())
        return (width: max(width, 0), height: max(height, 0), durationSeconds: max(duration, 0))
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
