import Foundation

class FeedService: FeedServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int
    private let anonService: AnonService
    private let anonQueryAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+/=&?"))
    
    init(apiClient: APIClient = APIClient(), defaultLimit: Int = 20, anonService: AnonService = .shared) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
        self.anonService = anonService
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
        let response: TrendingFeedResponseDTO = try await apiClient.get(endpoint)
        return response.items.map(TrendingPost.init(dto:))
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
        let response: FeedResponseDTO = try await apiClient.get(endpoint)
        let posts = response.items.map { Post(dto: $0) }
        return FeedPage(posts: posts, nextCursor: response.nextCursor)
    }
    
    func createPost(
        content: String,
        isAnonymous: Bool,
        communityId: Int,
        mediaAssetId: Int?,
        poll: PollDraft?
    ) async throws -> Post {
        let pollRequest = poll.flatMap(makePollRequest(from:))
        var request = CreatePostRequestDTO(
            content: content,
            mediaAssetId: mediaAssetId,
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
                mediaAssetId: mediaAssetId,
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
        let dto: PostDTO = try await apiClient.get(
            "/v1/posts/\(response.id)",
            requiresAuth: !isAnonymous
        )
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
            let dto: PostDTO = try await apiClient.put(
                "/v1/posts/\(postId)",
                body: request,
                requiresAuth: false,
                headers: ["X-Actor": "anon"]
            )
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
        let dto: PostDTO = try await apiClient.put(
            "/v1/posts/\(postId)",
            body: request
        )
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
        let dto: PostDTO = try await apiClient.get("/v1/posts/\(postId)")
        return Post(dto: dto)
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
        let response: FeedResponseDTO = try await apiClient.get(endpoint)
        let posts = response.items.map { Post(dto: $0) }
        return FeedPage(posts: posts, nextCursor: response.nextCursor)
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

        let response: FeedResponseDTO = try await apiClient.get(
            endpoint,
            requiresAuth: false,
            headers: ["X-Actor": "anon"]
        )
        let posts = response.items.map { Post(dto: $0) }
        return FeedPage(posts: posts, nextCursor: response.nextCursor)
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
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
