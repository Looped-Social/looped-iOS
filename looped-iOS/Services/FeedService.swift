import Foundation

class FeedService: FeedServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int
    
    init(apiClient: APIClient = APIClient(), defaultLimit: Int = 20) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
    }
    
    func fetchFeed(limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/feed", limit: limit, cursor: cursor)
    }
    
    func createPost(content: String, isAnonymous: Bool) async throws -> Post {
        let request = CreatePostRequestDTO(content: content, mediaAssetId: nil)
        let headers = ["Idempotency-Key": UUID().uuidString]
        let dto: PostDTO = try await apiClient.postWithHeaders("/v1/posts", body: request, headers: headers)
        return Post(dto: dto)
    }
    
    func reactToPost(postId: Int, reaction: ReactionType) async throws -> PostReactionResponse {
        // Backend currently supports "like" only. Ignore other reactions for now.
        _ = reaction
        let response: PostLikeResponseDTO = try await apiClient.post("/v1/posts/\(postId)/like", body: EmptyBody())
        return PostReactionResponse(postId: response.postId, likesCount: response.likesCount)
    }
    
    func fetchUserPosts(userId: Int, limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/users/\(userId)/posts", limit: limit, cursor: cursor)
    }
    
    func fetchLikedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/posts/liked", limit: limit, cursor: cursor)
    }
    
    func fetchSavedPosts(limit: Int, cursor: String?) async throws -> FeedPage {
        try await fetchPosts(from: "/v1/posts/saved", limit: limit, cursor: cursor)
    }
    
    func savePost(postId: Int) async throws -> Bool {
        let response: PostSaveResponseDTO = try await apiClient.post("/v1/posts/\(postId)/save", body: EmptyBody())
        return response.saved
    }
    
    func removeSavedPost(postId: Int) async throws -> Bool {
        let response: PostSaveResponseDTO = try await apiClient.delete("/v1/posts/\(postId)/save", expecting: PostSaveResponseDTO.self)
        return !response.saved
    }
    
    private func fetchPosts(from basePath: String, limit: Int, cursor: String?) async throws -> FeedPage {
        var endpoint = "\(basePath)?limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: FeedResponseDTO = try await apiClient.get(endpoint)
        let posts = response.items.map(Post.init(dto:))
        return FeedPage(posts: posts, nextCursor: response.nextCursor)
    }
}

private struct EmptyBody: Codable {}
