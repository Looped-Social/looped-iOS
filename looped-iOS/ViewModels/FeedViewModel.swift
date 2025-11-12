import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    
    private let feedService: FeedServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var nextCursor: String?
    private let pageSize = 20
    
    init(feedService: FeedServiceProtocol = MockConfig.useMockData ? MockFeedService() : FeedService()) {
        self.feedService = feedService
    }
    
    func loadPosts(reset: Bool = true) async {
        if reset {
            if isLoading { return }
            isLoading = true
        } else {
            if isLoadingMore || nextCursor == nil { return }
            isLoadingMore = true
        }
        errorMessage = nil
        if reset { nextCursor = nil }
        
        do {
            let page = try await feedService.fetchFeed(limit: pageSize, cursor: reset ? nil : nextCursor)
            if reset {
                posts = page.posts
            } else {
                posts.append(contentsOf: page.posts)
            }
            nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
        
        if reset {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }
    
    func refreshPosts() async {
        await loadPosts(reset: true)
    }

    func loadMoreIfNeeded(currentPost: Post) async {
        guard let lastPost = posts.last, currentPost.id == lastPost.id else { return }
        await loadPosts(reset: false)
    }
    
    func reactToPost(_ post: Post, reaction: ReactionType) async {
        guard let backendId = post.backendId else { return }
        do {
            let response = try await feedService.reactToPost(postId: backendId, reaction: reaction)
            if let index = posts.firstIndex(where: { $0.backendId == response.postId }) {
                posts[index] = posts[index].updating(
                    reactionCount: response.likesCount,
                    userReaction: .some(.like),
                    updatedAt: Date()
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createPost(content: String, isAnonymous: Bool = false, channel: String = "General") async {
        isLoading = true
        errorMessage = nil
        do {
            let newPost = try await feedService.createPost(content: content, isAnonymous: isAnonymous)
            posts.insert(newPost, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
