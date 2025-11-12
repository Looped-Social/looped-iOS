import Foundation

class FeedService: FeedServiceProtocol {
    private let apiClient: APIClient
    private let defaultLimit: Int
    
    init(apiClient: APIClient = APIClient(), defaultLimit: Int = 20) {
        self.apiClient = apiClient
        self.defaultLimit = defaultLimit
    }
    
    func fetchFeed(limit: Int, cursor: String?) async throws -> FeedPage {
        var endpoint = "/v1/feed?limit=\(limit > 0 ? limit : defaultLimit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: FeedResponseDTO = try await apiClient.get(endpoint)
        let posts = response.items.map(Post.init(dto:))
        return FeedPage(posts: posts, nextCursor: response.nextCursor)
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
}

private struct EmptyBody: Codable {}
