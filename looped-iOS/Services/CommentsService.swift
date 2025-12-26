import Foundation

class CommentsService: CommentsServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int
    private let anonService: AnonService
    private let anonHeaders = ["X-Actor": "anon"]

    init(
        apiClient: APIClient = APIClient(),
        defaultLimit: Int = 20,
        anonService: AnonService = .shared
    ) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
        self.anonService = anonService
    }

    func fetchComments(postId: Int, limit: Int, cursor: String?) async throws -> CommentPage {
        try await fetchComments(
            from: "/v1/posts/\(postId)/comments",
            limit: limit,
            cursor: cursor,
            anonAction: .commentList(postId: postId)
        )
    }

    func fetchReplies(commentId: Int, limit: Int, cursor: String?) async throws -> CommentPage {
        try await fetchComments(
            from: "/v1/comments/\(commentId)/replies",
            limit: limit,
            cursor: cursor,
            anonAction: .commentReplies(commentId: commentId)
        )
    }

    func createComment(postId: Int, content: String, parentId: Int?) async throws -> Comment {
        let request = try await makeCommentRequest(content: content, parentId: parentId, postId: postId)
        let isAnon = request.asAnon ?? false
        let dto: CommentDTO = try await apiClient.post(
            "/v1/posts/\(postId)/comments",
            body: request,
            requiresAuth: !isAnon,
            headers: isAnon ? anonHeaders : [:]
        )
        return Comment(dto: dto)
    }

    func likeComment(commentId: Int) async throws -> CommentLikeResponse {
        let request = try await makeCommentLikeRequest(commentId: commentId)
        let isAnon = request.asAnon ?? false
        let response: CommentLikeResponseDTO = try await apiClient.post(
            "/v1/comments/\(commentId)/like",
            body: request,
            requiresAuth: !isAnon,
            headers: isAnon ? anonHeaders : [:]
        )
        return CommentLikeResponse(
            commentId: response.commentId,
            likesCount: response.likesCount,
            userLiked: response.userLiked ?? true,
            likedByCreator: response.likedByCreator ?? false
        )
    }

    private func fetchComments(
        from basePath: String,
        limit: Int,
        cursor: String?,
        anonAction: AnonAction
    ) async throws -> CommentPage {
        var endpoint = "\(basePath)?limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        if anonService.isAnonymousEnabled {
            endpoint = try await appendAnonQuery(to: endpoint, action: anonAction)
        }
        let isAnon = anonService.isAnonymousEnabled
        let response: CommentListResponseDTO = try await apiClient.get(
            endpoint,
            requiresAuth: !isAnon,
            headers: isAnon ? anonHeaders : [:]
        )
        let comments = response.items.map(Comment.init(dto:))
        return CommentPage(comments: comments, nextCursor: response.nextCursor)
    }

    private func makeCommentRequest(content: String, parentId: Int?, postId: Int) async throws -> CreateCommentRequestDTO {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .comment(postId: postId))
            return CreateCommentRequestDTO(
                content: content,
                parentId: parentId,
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
        }
        return CreateCommentRequestDTO(
            content: content,
            parentId: parentId,
            asAnon: nil,
            anonProfileId: nil,
            anonCert: nil,
            anonCertKid: nil,
            anonSig: nil
        )
    }

    private func makeCommentLikeRequest(commentId: Int) async throws -> CommentLikeRequestDTO {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .commentLike(commentId: commentId))
            return CommentLikeRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
        }
        return CommentLikeRequestDTO(
            asAnon: nil,
            anonProfileId: nil,
            anonCert: nil,
            anonCertKid: nil,
            anonSig: nil
        )
    }

    private func appendAnonQuery(to endpoint: String, action: AnonAction) async throws -> String {
        let anonContext = try await anonService.actionContext(for: action)
        let encodedCert = anonContext.cert.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? anonContext.cert
        let encodedKid = anonContext.certKid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? anonContext.certKid
        let encodedSig = anonContext.signature.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? anonContext.signature
        let params = [
            "asAnon=true",
            "anonProfileId=\(anonContext.profileId)",
            "anonCert=\(encodedCert)",
            "anonCertKid=\(encodedKid)",
            "anonSig=\(encodedSig)"
        ]
        return endpoint + "&" + params.joined(separator: "&")
    }
}
