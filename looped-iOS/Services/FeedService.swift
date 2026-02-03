import Foundation

class FeedService: FeedServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int
    private let anonService: AnonService
    private let mediaService: MediaServiceProtocol
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
    
    func fetchFeed(limit: Int, cursor: String?, communityId: Int?, mode: FeedMode) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/feed", limit: limit, cursor: cursor, communityId: communityId, mode: mode)
    }

    func fetchTrendingPosts(limit: Int, communityId: Int?) async throws -> [TrendingPost] {
        let resolvedLimit = limit > 0 ? limit : 3
        var endpoint = "/v1/feed/trending?limit=\(resolvedLimit)"
        if let communityId {
            endpoint += "&communityId=\(communityId)"
        }
        let data = try await apiClient.getData(endpoint)
        let response = try decode(TrendingFeedResponseDTO.self, from: data)
        let posts = response.items.map(TrendingPost.init(dto:))
        return await resolveTrendingMediaIfNeeded(for: posts)
    }

    func searchPosts(query: String, limit: Int, cursor: String?) async throws -> FeedPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+/=&?#"))
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
        var endpoint = "/v1/posts/search?query=\(encoded)&limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor, !cursor.isEmpty {
            let encodedCursor = cursor.addingPercentEncoding(withAllowedCharacters: allowed) ?? cursor
            endpoint += "&cursor=\(encodedCursor)"
        }
        let data = try await apiClient.getData(endpoint)
        let response = try decode(FeedResponseDTO.self, from: data)
        let posts = response.items.map { Post(dto: $0) }
        let resolved = await resolveMediaIfNeeded(for: posts)
        return FeedPage(posts: resolved, nextCursor: response.nextCursor)
    }
    
    func createPost(
        content: String,
        isAnonymous: Bool,
        communityId: Int,
        mediaAssetId: Int?,
        mediaAssetIds: [Int]?,
        poll: PollDraft?
    ) async throws -> Post {
        let pollRequest = poll.flatMap(makePollRequest(from:))
        let normalizedMediaAssetIds = (mediaAssetIds ?? []).prefix(4)
        let resolvedMediaAssetId = normalizedMediaAssetIds.isEmpty ? mediaAssetId : nil
        var request = CreatePostRequestDTO(
            content: content,
            mediaAssetId: resolvedMediaAssetId,
            mediaAssetIds: normalizedMediaAssetIds.isEmpty ? nil : Array(normalizedMediaAssetIds),
            communityId: communityId,
            isAnon: nil,
            anonProfileId: nil,
            anonCert: nil,
            anonCertKid: nil,
            anonSig: nil,
            anonCompanyId: nil,
            anonTimestamp: nil,
            poll: pollRequest
        )
        var headers = ["Idempotency-Key": UUID().uuidString]

        if isAnonymous {
            let anonContext = try await anonService.postContext(content: content, communityId: communityId)
            request = CreatePostRequestDTO(
                content: content,
                mediaAssetId: resolvedMediaAssetId,
                mediaAssetIds: normalizedMediaAssetIds.isEmpty ? nil : Array(normalizedMediaAssetIds),
                communityId: communityId,
                isAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature,
                anonCompanyId: nil,
                anonTimestamp: anonContext.timestamp,
                poll: pollRequest
            )
            headers = ["X-Actor": "anon"]
        }

        let data = try await apiClient.postDataWithHeaders(
            "/v1/posts",
            body: request,
            headers: headers,
            requiresAuth: !isAnonymous
        )
        if let dto = tryDecodePost(from: data) {
            return Post(dto: dto, isAnonymousOverride: isAnonymous)
        }
        let response = try decode(CreatePostResponseDTO.self, from: data)
        let postData = try await apiClient.getData(
            "/v1/posts/\(response.id)",
            requiresAuth: !isAnonymous
        )
        let dto = try decode(PostDTO.self, from: postData)
        return Post(dto: dto, isAnonymousOverride: isAnonymous)
    }

    func updatePost(postId: Int, content: String, isAnonymous: Bool, communityId: Int?) async throws -> Post {
        if isAnonymous {
            let anonContext = try await anonService.actionContext(for: .postEdit(postId: postId), communityId: communityId)
            let request = UpdatePostRequestDTO(
                content: content,
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let data = try await apiClient.putData(
                "/v1/posts/\(postId)",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            let dto = try decode(PostDTO.self, from: data)
            return Post(dto: dto, isAnonymousOverride: true)
        }

        let request = UpdatePostRequestDTO(
            content: content,
            asAnon: nil,
            anonProfileId: nil,
            anonCert: nil,
            anonCertKid: nil,
            anonSig: nil
        )
        let data = try await apiClient.putData(
            "/v1/posts/\(postId)",
            body: request
        )
        let dto = try decode(PostDTO.self, from: data)
        return Post(dto: dto)
    }
    
    func reactToPost(postId: Int, communityId: Int?, reaction: ReactionType) async throws -> PostReactionResponse {
        // Backend currently supports "like" only. Ignore other reactions for now.
        _ = reaction
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .like(postId: postId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PostLikeResponseDTO = try await apiClient.post(
                "/v1/posts/\(postId)/like",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return PostReactionResponse(postId: response.postId, likesCount: response.likesCount)
        }

        let response: PostLikeResponseDTO = try await apiClient.post("/v1/posts/\(postId)/like", body: EmptyBody())
        return PostReactionResponse(postId: response.postId, likesCount: response.likesCount)
    }

    func unlikePost(postId: Int, communityId: Int?) async throws -> PostReactionResponse {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .unlike(postId: postId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PostLikeResponseDTO = try await apiClient.delete(
                "/v1/posts/\(postId)/like",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return PostReactionResponse(postId: response.postId, likesCount: response.likesCount)
        }

        let response: PostLikeResponseDTO = try await apiClient.delete(
            "/v1/posts/\(postId)/like",
            expecting: PostLikeResponseDTO.self
        )
        return PostReactionResponse(postId: response.postId, likesCount: response.likesCount)
    }

    func sharePost(postId: Int) async throws -> PostShareResponse {
        let response: PostShareResponseDTO = try await apiClient.post("/v1/posts/\(postId)/share", body: EmptyBody())
        return PostShareResponse(postId: response.postId, shareCount: response.shareCount)
    }

    func repostPost(postId: Int) async throws -> PostRepostResponse {
        let response: PostRepostResponseDTO
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .repost(postId: postId), communityId: nil)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            response = try await apiClient.put(
                "/v1/posts/\(postId)/repost",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
        } else {
            response = try await apiClient.put(
                "/v1/posts/\(postId)/repost",
                body: EmptyBody()
            )
        }
        return PostRepostResponse(
            postId: response.postId,
            repostCount: response.repostCount,
            viewerHasReposted: response.viewerHasReposted
        )
    }

    func unrepostPost(postId: Int) async throws -> PostRepostResponse {
        let response: PostRepostResponseDTO
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .unrepost(postId: postId), communityId: nil)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            response = try await apiClient.delete(
                "/v1/posts/\(postId)/repost",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
        } else {
            response = try await apiClient.delete(
                "/v1/posts/\(postId)/repost",
                expecting: PostRepostResponseDTO.self
            )
        }
        return PostRepostResponse(
            postId: response.postId,
            repostCount: response.repostCount,
            viewerHasReposted: response.viewerHasReposted
        )
    }
    
    func fetchUserPosts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/users/\(userId)/posts", limit: limit, cursor: cursor, communityId: nil)
    }

    func fetchHashtagPosts(hashtag: String, limit: Int, cursor: String?) async throws -> FeedPage {
        let trimmed = hashtag.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleaned
        let base = "/v1/hashtags/\(encoded)/posts"
        return try await fetchPosts(from: base, limit: limit, cursor: cursor, communityId: nil)
    }

    func fetchPost(postId: Int) async throws -> Post {
        let data = try await apiClient.getData("/v1/posts/\(postId)")
        let dto = try decode(PostDTO.self, from: data)
        return await resolveMediaIfNeeded(for: Post(dto: dto))
    }
    
    func fetchLikedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        if anonService.isAnonymousEnabled {
            return try await fetchAnonCollection(action: .postsLiked, limit: limit, cursor: cursor)
        }
        return try await fetchPosts(from: "/v1/posts/liked", limit: limit, cursor: cursor, communityId: nil)
    }
    
    func fetchSavedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        if anonService.isAnonymousEnabled {
            return try await fetchAnonCollection(action: .postsSaved, limit: limit, cursor: cursor)
        }
        return try await fetchPosts(from: "/v1/posts/saved", limit: limit, cursor: cursor, communityId: nil)
    }

    func fetchRepostedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/posts/reposted", limit: limit, cursor: cursor, communityId: nil)
    }

    func fetchUserReposts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/users/\(userId)/reposts", limit: limit, cursor: cursor, communityId: nil)
    }

    func fetchMyReposts(limit: Int, cursor: String?) async throws -> FeedPage {
        do {
            return try await fetchPosts(from: "/v1/users/me/reposts", limit: limit, cursor: cursor, communityId: nil)
        } catch {
            guard isNotFound(error) else { throw error }
            return try await fetchRepostedPosts(limit: limit, cursor: cursor)
        }
    }

    func fetchAnonReposts(anonProfileId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/anon/\(anonProfileId)/reposts", limit: limit, cursor: cursor, communityId: nil)
    }

    func fetchMyContent(limit: Int, cursor: String?, includePostPreview: Bool) async throws -> UserContentPage {
        try await fetchContentPage(
            endpoint: "/v1/users/me/content",
            limit: limit,
            cursor: cursor,
            includePostPreview: includePostPreview
        )
    }

    func fetchUserContent(userId: Int, limit: Int, cursor: String?, includePostPreview: Bool) async throws -> UserContentPage {
        try await fetchContentPage(
            endpoint: "/v1/users/\(userId)/content",
            limit: limit,
            cursor: cursor,
            includePostPreview: includePostPreview
        )
    }

    func fetchAnonContent(anonProfileId: Int, limit: Int, cursor: String?, includePostPreview: Bool) async throws -> UserContentPage {
        try await fetchContentPage(
            endpoint: "/v1/anon/\(anonProfileId)/content",
            limit: limit,
            cursor: cursor,
            includePostPreview: includePostPreview
        )
    }

    private func fetchContentPage(
        endpoint: String,
        limit: Int,
        cursor: String?,
        includePostPreview: Bool
    ) async throws -> UserContentPage {
        var resolved = "\(endpoint)?limit=\(limit > 0 ? limit : defaultLimit)"
        if includePostPreview {
            resolved += "&include_post_preview=true"
        }
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            resolved += "&cursor=\(encoded)"
        }
        let data = try await apiClient.getData(resolved)
        let response = try decode(UserContentResponseDTO.self, from: data)
        let items = response.items.compactMap(UserContentItem.init(dto:))
        let resolvedItems = await resolveMediaIfNeeded(for: items)
        return UserContentPage(items: resolvedItems, nextCursor: response.nextCursor)
    }

    private func resolveMediaIfNeeded(for items: [UserContentItem]) async -> [UserContentItem] {
        let posts: [Post] = items.flatMap { item -> [Post] in
            switch item.payload {
            case .post(let post):
                return [post]
            case .reply(_, let postPreview):
                return postPreview.map { [$0] } ?? []
            }
        }

        guard !posts.isEmpty else { return items }

        let resolvedPosts = await resolveMediaIfNeeded(for: posts)
        var byId: [UUID: Post] = [:]
        byId.reserveCapacity(resolvedPosts.count)
        for post in resolvedPosts {
            byId[post.id] = post
        }

        return items.map { item in
            switch item.payload {
            case .post(let post):
                let resolvedPost = byId[post.id] ?? post
                return UserContentItem(id: item.id, createdAt: item.createdAt, payload: .post(resolvedPost))
            case .reply(let reply, let postPreview):
                let resolvedPreview = postPreview.map { byId[$0.id] ?? $0 }
                return UserContentItem(id: item.id, createdAt: item.createdAt, payload: .reply(reply, postPreview: resolvedPreview))
            }
        }
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

    func fetchAnonPosts(anonProfileId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/anon/\(anonProfileId)/posts", limit: limit, cursor: cursor, communityId: nil)
    }
    
    func savePost(postId: Int, communityId: Int?) async throws -> Bool {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .save(postId: postId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PostSaveResponseDTO = try await apiClient.post(
                "/v1/posts/\(postId)/save",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return response.saved
        }

        let response: PostSaveResponseDTO = try await apiClient.post("/v1/posts/\(postId)/save", body: EmptyBody())
        return response.saved
    }
    
    func removeSavedPost(postId: Int, communityId: Int?) async throws -> Bool {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .unsave(postId: postId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PostSaveResponseDTO = try await apiClient.delete(
                "/v1/posts/\(postId)/save",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return !response.saved
        }

        let response: PostSaveResponseDTO = try await apiClient.delete("/v1/posts/\(postId)/save", expecting: PostSaveResponseDTO.self)
        return !response.saved
    }

    func deletePost(postId: Int, communityId: Int?, asAnon: Bool) async throws -> PostDeleteResponse {
        if asAnon {
            let anonContext = try await anonService.actionContext(for: .postDelete(postId: postId), communityId: communityId)
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PostDeleteResponseDTO = try await apiClient.delete(
                "/v1/posts/\(postId)",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
            return PostDeleteResponse(postId: response.id, deleted: response.deleted)
        }

        let response: PostDeleteResponseDTO = try await apiClient.delete(
            "/v1/posts/\(postId)",
            expecting: PostDeleteResponseDTO.self
        )
        return PostDeleteResponse(postId: response.id, deleted: response.deleted)
    }
    
    private func fetchPosts(
        from basePath: String,
        limit: Int,
        cursor: String?,
        communityId: Int?,
        mode: FeedMode? = nil
    ) async throws -> FeedPage {
        var endpoint = "\(basePath)?limit=\(limit > 0 ? limit : defaultLimit)"
        if let mode {
            endpoint += "&mode=\(mode.rawValue)"
        }
        if let communityId {
            endpoint += "&communityId=\(communityId)"
        }
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let data = try await apiClient.getData(endpoint)
        let response = try decode(FeedResponseDTO.self, from: data)
        let posts = response.items.map { Post(dto: $0) }
        let resolved = await resolveMediaIfNeeded(for: posts)
        return FeedPage(posts: resolved, nextCursor: response.nextCursor)
    }

    private func fetchAnonCollection(
        action: AnonProfileAction,
        limit: Int,
        cursor: String?
    ) async throws -> FeedPage {
        let anonContext = try await anonService.profileActionContext(for: action)
        let path: String
        switch action {
        case .postsLiked:
            path = "/v1/anon/\(anonContext.profileId)/posts/liked"
        case .postsSaved:
            path = "/v1/anon/\(anonContext.profileId)/posts/saved"
        case .replies:
            throw APIError.invalidResponse
        }

        var endpoint = "\(path)?limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        endpoint = appendAnonQuery(to: endpoint, context: anonContext)

        let data = try await apiClient.getData(
            endpoint,
            requiresAuth: false,
            headers: ["X-Actor": "anon"]
        )
        let response = try decode(FeedResponseDTO.self, from: data)
        let posts = response.items.map { Post(dto: $0) }
        let resolved = await resolveMediaIfNeeded(for: posts)
        return FeedPage(posts: resolved, nextCursor: response.nextCursor)
    }

    private func appendAnonQuery(to endpoint: String, context: AnonActionContext) -> String {
        let encodedCert = context.cert.addingPercentEncoding(withAllowedCharacters: anonQueryAllowed) ?? context.cert
        let encodedKid = context.certKid.addingPercentEncoding(withAllowedCharacters: anonQueryAllowed) ?? context.certKid
        let encodedSig = context.signature.addingPercentEncoding(withAllowedCharacters: anonQueryAllowed) ?? context.signature
        let params = [
            "asAnon=true",
            "anonProfileId=\(context.profileId)",
            "anonCert=\(encodedCert)",
            "anonCertKid=\(encodedKid)",
            "anonSig=\(encodedSig)"
        ]
        return endpoint + "&" + params.joined(separator: "&")
    }
}

private extension FeedService {
    func resolveTrendingMediaIfNeeded(for posts: [TrendingPost]) async -> [TrendingPost] {
        let assetIds = posts
            .flatMap { ($0.mediaAssetIds ?? []).filter { $0 > 0 } }
        let uniqueIds = Array(Set(assetIds))
        guard !uniqueIds.isEmpty else { return posts }

        do {
            let assets = try await mediaService.resolvePublicMedia(ids: uniqueIds)
            let byId = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
            return posts.map { post in
                guard let previewId = post.mediaAssetIds?.first, let asset = byId[previewId] else { return post }
                let mimeType = asset.mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isVideo = mimeType.hasPrefix("video/") || asset.durationSeconds != nil
                let candidateUrl = isVideo ? (asset.thumbnailUrl ?? asset.cdnUrl) : asset.cdnUrl
                let trimmed = (candidateUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return post }
                return post.updating(imageURL: trimmed)
            }
        } catch {
            return posts
        }
    }

    func resolveMediaIfNeeded(for post: Post) async -> Post {
        let resolved = await resolveMediaIfNeeded(for: [post])
        return resolved.first ?? post
    }

    func resolveMediaIfNeeded(for posts: [Post]) async -> [Post] {
        let missingIds: [Int] = posts.flatMap { post -> [Int] in
            let ids = (post.mediaAssetIds ?? []).filter { $0 > 0 }
            if !ids.isEmpty {
                // Always prefer the canonical media resolve response when IDs are present.
                // Some endpoints also populate legacy `cdnUrl`/`mediaUrl` fields (often a thumbnail for videos).
                return ids
            }
            if let id = post.mediaAssetId, id > 0 { return [id] }
            return []
        }
        let uniqueIds = Array(Set(missingIds))
        guard !uniqueIds.isEmpty else { return posts }

        do {
            let assets = try await mediaService.resolvePublicMedia(ids: uniqueIds)
            if ProcessInfo.processInfo.environment["LOOPED_LOG_MEDIA_RESOLVE"] == "1" {
                let videoCount = assets.filter { asset in
                    let mime = asset.mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return mime.hasPrefix("video/") || asset.durationSeconds != nil
                }.count
                print("Feed media resolve ids=\(uniqueIds.count) assets=\(assets.count) videos=\(videoCount)")
            }
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

            if byId.isEmpty { return posts }
            return posts.map { post in
                let resolvedIds = (post.mediaAssetIds ?? []).filter { $0 > 0 }
                if !resolvedIds.isEmpty {
                    let attachments = resolvedIds.compactMap { byId[$0] }
                    guard attachments.count == resolvedIds.count, !attachments.isEmpty else { return post }
                    return post.updating(attachments: .some(attachments))
                }
                guard let mediaAssetId = post.mediaAssetId, let attachment = byId[mediaAssetId] else { return post }
                return post.updating(attachments: .some([attachment]))
            }
        } catch {
            return posts
        }
    }

    func makePollRequest(from draft: PollDraft) -> CreatePostPollRequestDTO? {
        guard draft.isValid else { return nil }
        let question = draft.question.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = draft.normalizedOptions
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let closesAt = draft.closesAt.map { formatter.string(from: $0) }
        return CreatePostPollRequestDTO(
            question: question,
            options: options,
            maxSelections: 1,
            closesAt: closesAt
        )
    }

    func tryDecodePost(from data: Data) -> PostDTO? {
        try? decode(PostDTO.self, from: data)
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = FeedService.iso8601FormatterWithFractional.date(from: value)
                ?? FeedService.iso8601Formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        decoder.keyDecodingStrategy = .custom { codingPath in
            guard let last = codingPath.last else { return AnyCodingKey(stringValue: "") }
            let rawKey = last.stringValue
            if rawKey == "media_asset_ids" {
                return AnyCodingKey(stringValue: "mediaAssetIdsSnake")
            }
            return AnyCodingKey(stringValue: FeedService.convertFromSnakeCase(rawKey))
        }
        return try decoder.decode(T.self, from: data)
    }
}

private extension FeedService {
    static let iso8601FormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct EmptyBody: Codable {}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension FeedService {
    static func convertFromSnakeCase(_ stringKey: String) -> String {
        guard stringKey.contains("_") else { return stringKey }
        let components = stringKey.split(separator: "_")
        guard let first = components.first else { return stringKey }
        let rest = components.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return ([String(first)] + rest).joined()
    }
}
