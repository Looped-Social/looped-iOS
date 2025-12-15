import SwiftUI
import Combine

@MainActor
class CommentsModalManager: ObservableObject {
    @Published var isPresented = false
    @Published var currentPost: Post?
    @Published var currentComments: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isPosting = false
    @Published var errorMessage: String?
    @Published var replyThreads: [Int: ReplyThreadState] = [:]
    @Published var replyTarget: Comment?
    
    private let commentsService: CommentsServiceProtocol
    private var nextCursor: String?
    private var currentPostBackendId: Int?
    private let pageSize = 20
    
    init(commentsService: CommentsServiceProtocol = CommentsService()) {
        self.commentsService = commentsService
    }
    
    func showComments(for post: Post) {
        guard let backendId = post.backendId else { return }
        currentPost = post
        currentPostBackendId = backendId
        currentComments = []
        nextCursor = nil
        errorMessage = nil
        replyThreads = [:]
        replyTarget = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPresented = true
        }
        Task { await loadComments(reset: true) }
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
            let page = try await commentsService.fetchReplies(commentId: commentId, limit: pageSize, cursor: reset ? nil : state.nextCursor)
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
        state.isExpanded.toggle()
        replyThreads[backendId] = state

        if state.isExpanded && state.replies.isEmpty {
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
    }

    func clearReplyTarget() {
        replyTarget = nil
    }

    func postComment(content: String) async {
        guard let postId = currentPostBackendId, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isPosting else { return }
        isPosting = true
        defer { isPosting = false }

        do {
            let parentId = replyTarget?.backendId
            let comment = try await commentsService.createComment(postId: postId, content: content, parentId: parentId)
            if let parentId = parentId {
                var state = replyThreads[parentId] ?? ReplyThreadState(isExpanded: true)
                state.replies.append(comment)
                replyThreads[parentId] = state
            } else {
                currentComments.append(comment)
            }
            if let post = currentPost {
                currentPost = post.updating(commentsCount: post.commentsCount + 1)
            }
            replyTarget = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(for comment: Comment) async {
        guard let backendId = comment.backendId else { return }
        do {
            let response = try await commentsService.likeComment(commentId: backendId)
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
            let page = try await commentsService.fetchComments(postId: postId, limit: pageSize, cursor: reset ? nil : nextCursor)
            if reset {
                currentComments = page.comments
            } else {
                currentComments.append(contentsOf: page.comments)
            }
            nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
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
