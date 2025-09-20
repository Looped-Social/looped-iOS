import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let feedService: FeedServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(feedService: FeedServiceProtocol = MockConfig.useMockData ? MockFeedService() : FeedService()) {
        self.feedService = feedService
    }
    
    func loadPosts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedPosts = try await feedService.getPosts()
            posts = fetchedPosts
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refreshPosts() async {
        await loadPosts()
    }
    
    func reactToPost(_ post: Post, reaction: ReactionType) async {
        do {
            try await feedService.reactToPost(postId: post.id, reaction: reaction)
            await loadPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createPost(content: String, isAnonymous: Bool = false, channel: String = "General") async {
        isLoading = true
        errorMessage = nil
        
        // Create the new post using MockPosts helper
        let newPost = MockPosts.createPost(content: content, isAnonymous: isAnonymous)
        
        // Add to the beginning of the posts array (newest first)
        posts.insert(newPost, at: 0)
        
        isLoading = false
        
        // In a real app, this would make an API call to create the post
        // For now, we just add it to the local array
    }
}