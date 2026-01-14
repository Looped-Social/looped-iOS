import Foundation

class CommentsService: CommentsServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int
    private let anonService: AnonService
    private let mediaService: MediaServiceProtocol
    private let anonHeaders = ["X-Actor": "anon"]
    private let anonQueryAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+/=&?"))

    init(
        apiClient: APIClient = APIClient(),
        defaultLimit: Int = 20,
        anonService: AnonService = .shared,
        mediaService: MediaServiceProtocol = MediaService()
    ) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
        self.anonService = anonService
        self.mediaService = mediaService
    }

    func fetchComments(postId: Int, communityId: Int?, limit: Int, cursor: String?) async throws -> CommentPage {
        let page = try await fetchComments(
            from: "/v1/posts/\(postId)/comments",
            limit: limit,
            cursor: cursor,
            anonAction: .commentList(postId: postId),
            communityId: communityId
        )
        return await resolveMediaIfNeeded(in: page)
    }

    func fetchReplies(commentId: Int, communityId: Int?, limit: Int, cursor: String?) async throws -> CommentPage {
        let page = try await fetchComments(
            from: "/v1/comments/\(commentId)/replies",
            limit: limit,
            cursor: cursor,
            anonAction: .commentReplies(commentId: commentId),
            communityId: communityId
        )
        return await resolveMediaIfNeeded(in: page)
    }

    func createComment(postId: Int, communityId: Int?, content: String, parentId: Int?, mediaAssetId: Int?) async throws -> Comment {
        let request = try await makeCommentRequest(
            content: content,
            parentId: parentId,
            postId: postId,
            communityId: communityId,
            mediaAssetId: mediaAssetId
        )
        let isAnon = request.asAnon ?? false
        let dto: CommentDTO = try await apiClient.post(
            "/v1/posts/\(postId)/comments",
            body: request,
            requiresAuth: !isAnon,
            headers: isAnon ? anonHeaders : [:]
        )
        return Comment(dto: dto)
    }

    func editComment(commentId: Int, communityId: Int?, content: String, asAnon: Bool) async throws -> Comment {
        let request = try await makeCommentEditRequest(
            commentId: commentId,
            communityId: communityId,
            content: content,
            asAnon: asAnon
        )
        let isAnon = request.asAnon ?? false
        let dto: CommentDTO = try await apiClient.put(
            "/v1/comments/\(commentId)",
            body: request,
            requiresAuth: !isAnon,
            headers: isAnon ? anonHeaders : [:]
        )
        return Comment(dto: dto)
    }

    func deleteComment(commentId: Int, communityId: Int?, asAnon: Bool) async throws -> CommentDeleteResponse {
        if asAnon {
            let anonContext = try await anonService.actionContext(for: .commentDelete(commentId: commentId), communityId: communityId)
            let request = CommentDeleteRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: CommentDeleteResponseDTO = try await apiClient.delete(
                "/v1/comments/\(commentId)",
                body: request,
                requiresAuth: false,
                headers: anonHeaders
            )
            return CommentDeleteResponse(commentId: response.id, deleted: response.deleted)
        }

        let response: CommentDeleteResponseDTO = try await apiClient.delete(
            "/v1/comments/\(commentId)",
            expecting: CommentDeleteResponseDTO.self
        )
        return CommentDeleteResponse(commentId: response.id, deleted: response.deleted)
    }

    func likeComment(commentId: Int, communityId: Int?) async throws -> CommentLikeResponse {
        let request = try await makeCommentLikeRequest(commentId: commentId, communityId: communityId)
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

    func unlikeComment(commentId: Int, communityId: Int?) async throws -> CommentLikeResponse {
        let request = try await makeCommentLikeRequest(commentId: commentId, communityId: communityId)
        let isAnon = request.asAnon ?? false
        let response: CommentLikeResponseDTO
        if isAnon {
            response = try await apiClient.delete(
                "/v1/comments/\(commentId)/like",
                body: request,
                requiresAuth: false,
                headers: anonHeaders
            )
        } else {
            response = try await apiClient.delete(
                "/v1/comments/\(commentId)/like",
                expecting: CommentLikeResponseDTO.self
            )
        }
        return CommentLikeResponse(
            commentId: response.commentId,
            likesCount: response.likesCount,
            userLiked: response.userLiked ?? false,
            likedByCreator: response.likedByCreator ?? false
        )
    }

    private func fetchComments(
        from basePath: String,
        limit: Int,
        cursor: String?,
        anonAction: AnonAction,
        communityId: Int?
    ) async throws -> CommentPage {
        var endpoint = "\(basePath)?limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        if anonService.isAnonymousEnabled {
            endpoint = try await appendAnonQuery(to: endpoint, action: anonAction, communityId: communityId)
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

    private func makeCommentRequest(
        content: String,
        parentId: Int?,
        postId: Int,
        communityId: Int?,
        mediaAssetId: Int?
    ) async throws -> CreateCommentRequestDTO {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .comment(postId: postId), communityId: communityId)
            return CreateCommentRequestDTO(
                content: content,
                parentId: parentId,
                mediaAssetId: mediaAssetId,
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
            mediaAssetId: mediaAssetId,
            asAnon: nil,
            anonProfileId: nil,
            anonCert: nil,
            anonCertKid: nil,
            anonSig: nil
        )
    }

    private func makeCommentEditRequest(commentId: Int, communityId: Int?, content: String, asAnon: Bool) async throws -> EditCommentRequestDTO {
        if asAnon {
            let anonContext = try await anonService.actionContext(for: .commentEdit(commentId: commentId), communityId: communityId)
            return EditCommentRequestDTO(
                content: content,
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
        }
        return EditCommentRequestDTO(
            content: content,
            asAnon: nil,
            anonProfileId: nil,
            anonCert: nil,
            anonCertKid: nil,
            anonSig: nil
        )
    }

    private func makeCommentLikeRequest(commentId: Int, communityId: Int?) async throws -> CommentLikeRequestDTO {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .commentLike(commentId: commentId), communityId: communityId)
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

    private func appendAnonQuery(to endpoint: String, action: AnonAction, communityId: Int?) async throws -> String {
        let anonContext = try await anonService.actionContext(for: action, communityId: communityId)
        let encodedCert = anonContext.cert.addingPercentEncoding(withAllowedCharacters: anonQueryAllowed) ?? anonContext.cert
        let encodedKid = anonContext.certKid.addingPercentEncoding(withAllowedCharacters: anonQueryAllowed) ?? anonContext.certKid
        let encodedSig = anonContext.signature.addingPercentEncoding(withAllowedCharacters: anonQueryAllowed) ?? anonContext.signature
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

private extension CommentsService {
    func resolveMediaIfNeeded(in page: CommentPage) async -> CommentPage {
        let ids: [Int] = page.comments.compactMap { comment in
            guard comment.attachments?.isEmpty ?? true else { return nil }
            return comment.mediaAssetId
        }
        let uniqueIds = Array(Set(ids))
        guard !uniqueIds.isEmpty else { return page }

        do {
            let assets = try await mediaService.resolvePublicMedia(ids: uniqueIds)
            let byId = Dictionary(uniqueKeysWithValues: assets.compactMap { asset -> (Int, MediaAttachment)? in
                guard let url = asset.cdnUrl, !url.isEmpty else { return nil }
                let type: MediaType = asset.mimeType.lowercased().hasPrefix("video/") ? .video : .image
                return (asset.id, MediaAttachment(type: type, url: url))
            })
            if byId.isEmpty { return page }
            let resolved = page.comments.map { comment in
                guard comment.attachments?.isEmpty ?? true else { return comment }
                guard let mediaAssetId = comment.mediaAssetId,
                      let attachment = byId[mediaAssetId]
                else { return comment }
                return comment.updating(attachments: .some([attachment]))
            }
            return CommentPage(comments: resolved, nextCursor: page.nextCursor)
        } catch {
            return page
        }
    }
}
