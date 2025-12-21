import Foundation

class FeedService: FeedServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int
    private let anonService: AnonService
    
    init(apiClient: APIClient = APIClient(), defaultLimit: Int = 20, anonService: AnonService = .shared) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
        self.anonService = anonService
    }
    
    func fetchFeed(limit: Int, cursor: String?, communityId: Int?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/feed", limit: limit, cursor: cursor, communityId: communityId)
    }
    
    func createPost(content: String, isAnonymous: Bool, communityId: Int) async throws -> Post {
        var request = CreatePostRequestDTO(
            content: content,
            mediaAssetId: nil,
            communityId: communityId,
            isAnon: nil,
            anonProfileId: nil,
            anonCert: nil,
            anonCertKid: nil,
            anonSig: nil,
            anonCompanyId: nil,
            anonTimestamp: nil
        )
        var headers = ["Idempotency-Key": UUID().uuidString]

        if isAnonymous {
            let anonContext = try await anonService.postContext(content: content, communityId: communityId)
            request = CreatePostRequestDTO(
                content: content,
                mediaAssetId: nil,
                communityId: communityId,
                isAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature,
                anonCompanyId: anonContext.companyId,
                anonTimestamp: anonContext.timestamp
            )
            headers = [:]
        }

        let dto: PostDTO = try await apiClient.postWithHeaders("/v1/posts", body: request, headers: headers)
        return Post(dto: dto, isAnonymousOverride: isAnonymous)
    }
    
    func reactToPost(postId: Int, reaction: ReactionType) async throws -> PostReactionResponse {
        // Backend currently supports "like" only. Ignore other reactions for now.
        _ = reaction
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .like(postId: postId))
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PostLikeResponseDTO = try await apiClient.post("/v1/posts/\(postId)/like", body: request)
            return PostReactionResponse(postId: response.postId, likesCount: response.likesCount)
        }

        let response: PostLikeResponseDTO = try await apiClient.post("/v1/posts/\(postId)/like", body: EmptyBody())
        return PostReactionResponse(postId: response.postId, likesCount: response.likesCount)
    }
    
    func fetchUserPosts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/users/\(userId)/posts", limit: limit, cursor: cursor, communityId: nil)
    }
    
    func fetchLikedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/posts/liked", limit: limit, cursor: cursor, communityId: nil)
    }
    
    func fetchSavedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/posts/saved", limit: limit, cursor: cursor, communityId: nil)
    }
    
    func savePost(postId: Int) async throws -> Bool {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .save(postId: postId))
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PostSaveResponseDTO = try await apiClient.post("/v1/posts/\(postId)/save", body: request)
            return response.saved
        }

        let response: PostSaveResponseDTO = try await apiClient.post("/v1/posts/\(postId)/save", body: EmptyBody())
        return response.saved
    }
    
    func removeSavedPost(postId: Int) async throws -> Bool {
        if anonService.isAnonymousEnabled {
            let anonContext = try await anonService.actionContext(for: .unsave(postId: postId))
            let request = AnonActionRequestDTO(
                asAnon: true,
                anonProfileId: anonContext.profileId,
                anonCert: anonContext.cert,
                anonCertKid: anonContext.certKid,
                anonSig: anonContext.signature
            )
            let response: PostSaveResponseDTO = try await apiClient.delete("/v1/posts/\(postId)/save", body: request)
            return !response.saved
        }

        let response: PostSaveResponseDTO = try await apiClient.delete("/v1/posts/\(postId)/save", expecting: PostSaveResponseDTO.self)
        return !response.saved
    }
    
    private func fetchPosts(from basePath: String, limit: Int, cursor: String?, communityId: Int?) async throws -> FeedPage {
        var endpoint = "\(basePath)?limit=\(limit > 0 ? limit : defaultLimit)"
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
}

private struct EmptyBody: Codable {}
