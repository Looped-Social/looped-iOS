import Foundation

class FeedService: FeedServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func getPosts() async throws -> [Post] {
        return try await apiClient.get("/feed/posts")
    }
    
    func createPost(content: String, isAnonymous: Bool) async throws -> Post {
        let request = CreatePostRequest(content: content, isAnonymous: isAnonymous)
        return try await apiClient.post("/feed/posts", body: request)
    }
    
    func reactToPost(postId: UUID, reaction: ReactionType) async throws {
        let request = ReactToPostRequest(postId: postId, reaction: reaction)
        let _: EmptyResponse = try await apiClient.post("/feed/posts/\(postId)/react", body: request)
    }
}

private struct CreatePostRequest: Codable {
    let content: String
    let isAnonymous: Bool
}

private struct ReactToPostRequest: Codable {
    let postId: UUID
    let reaction: ReactionType
}