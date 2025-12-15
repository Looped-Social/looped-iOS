import Foundation

class CommentsService: CommentsServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int

    init(apiClient: APIClient = APIClient(), defaultLimit: Int = 20) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
    }

    func fetchComments(postId: Int, limit: Int, cursor: String?) async throws -> CommentPage {
        try await fetchComments(from: "/v1/posts/\(postId)/comments", limit: limit, cursor: cursor)
    }

    func fetchReplies(commentId: Int, limit: Int, cursor: String?) async throws -> CommentPage {
        try await fetchComments(from: "/v1/comments/\(commentId)/replies", limit: limit, cursor: cursor)
    }

    func createComment(postId: Int, content: String, parentId: Int?) async throws -> Comment {
        let request = CreateCommentRequestDTO(content: content, parentId: parentId)
        let dto: CommentDTO = try await apiClient.post("/v1/posts/\(postId)/comments", body: request)
        return Comment(dto: dto)
    }

    func likeComment(commentId: Int) async throws -> CommentLikeResponse {
        let response: CommentLikeResponseDTO = try await apiClient.post("/v1/comments/\(commentId)/like", body: EmptyBody())
        return CommentLikeResponse(
            commentId: response.commentId,
            likesCount: response.likesCount,
            userLiked: response.userLiked ?? true,
            likedByCreator: response.likedByCreator ?? false
        )
    }

    private func fetchComments(from basePath: String, limit: Int, cursor: String?) async throws -> CommentPage {
        var endpoint = "\(basePath)?limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: CommentListResponseDTO = try await apiClient.get(endpoint)
        let comments = response.items.map(Comment.init(dto:))
        return CommentPage(comments: comments, nextCursor: response.nextCursor)
    }
}

private struct EmptyBody: Codable {}
