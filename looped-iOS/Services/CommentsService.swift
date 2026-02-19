import Foundation

class CommentsService: CommentsServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int
    private let anonService: AnonService
    private let mediaService: MediaServiceProtocol
    private let anonHeaders = ["X-Actor": "anon"]

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

    func fetchComments(postId: Int, communityId _: Int?, limit: Int, cursor: String?) async throws -> CommentPage {
        let page = try await fetchCommentsWithPublicFallback(
            privatePath: "/v1/posts/\(postId)/comments",
            publicPath: "/v1/public/posts/\(postId)/comments",
            limit: limit,
            cursor: cursor
        )
        return await resolveMediaIfNeeded(in: page)
    }

    func fetchReplies(commentId: Int, communityId _: Int?, limit: Int, cursor: String?) async throws -> CommentPage {
        let page = try await fetchCommentsWithPublicFallback(
            privatePath: "/v1/comments/\(commentId)/replies",
            publicPath: "/v1/public/comments/\(commentId)/replies",
            limit: limit,
            cursor: cursor
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

    private func fetchCommentsWithPublicFallback(
        privatePath: String,
        publicPath: String,
        limit: Int,
        cursor: String?
    ) async throws -> CommentPage {
        do {
            let privatePage = try await fetchComments(
                from: privatePath,
                limit: limit,
                cursor: cursor,
                requiresAuth: true
            )
            // Some restricted auth contexts can return empty reply sets even when
            // public read access is available. Try public read once on empty first page.
            if cursor == nil, privatePage.comments.isEmpty {
                if let publicPage = try? await fetchComments(
                    from: publicPath,
                    limit: limit,
                    cursor: cursor,
                    requiresAuth: false
                ), !publicPage.comments.isEmpty {
                    return publicPage
                }
            }
            return privatePage
        } catch {
            guard shouldFallbackToPublicCommentsRead(error) else {
                throw error
            }
            return try await fetchComments(
                from: publicPath,
                limit: limit,
                cursor: cursor,
                requiresAuth: false
            )
        }
    }

    private func fetchComments(
        from basePath: String,
        limit: Int,
        cursor: String?,
        requiresAuth: Bool
    ) async throws -> CommentPage {
        var endpoint = "\(basePath)?limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: CommentListResponseDTO = try await apiClient.get(
            endpoint,
            requiresAuth: requiresAuth
        )
        let comments = response.items.map(Comment.init(dto:))
        return CommentPage(comments: comments, nextCursor: response.nextCursor)
    }

    private func shouldFallbackToPublicCommentsRead(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .unauthorized:
            return true
        case .serverError(let code):
            return code == 403
        case .apiError(let code, let errorCode, _):
            guard code == 403 else { return false }
            return errorCode != "community_banned"
        default:
            return false
        }
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

}

private extension CommentsService {
    func resolveMediaIfNeeded(in page: CommentPage) async -> CommentPage {
        let ids: [Int] = page.comments.compactMap(\.mediaAssetId)
        let uniqueIds = Array(Set(ids))
        guard !uniqueIds.isEmpty else { return page }

        do {
            let assets = try await mediaService.resolvePublicMedia(ids: uniqueIds)
            let byId = Dictionary(uniqueKeysWithValues: assets.compactMap { asset -> (Int, MediaAttachment)? in
                let url = (asset.cdnUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !url.isEmpty else { return nil }
                let mimeType = asset.mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
                let isVideo = mimeType.lowercased().hasPrefix("video/") || asset.durationSeconds != nil
                let type: MediaType = isVideo ? .video : .image
                let thumbnailUrl = isVideo ? asset.thumbnailUrl : nil
                let duration = asset.durationSeconds.map(TimeInterval.init)
                return (
                    asset.id,
                    MediaAttachment(
                        id: "asset:\(asset.id)",
                        type: type,
                        url: url,
                        thumbnailUrl: thumbnailUrl,
                        width: asset.width,
                        height: asset.height,
                        duration: duration
                    )
                )
            })
            if byId.isEmpty { return page }
            let resolved = page.comments.map { comment in
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
