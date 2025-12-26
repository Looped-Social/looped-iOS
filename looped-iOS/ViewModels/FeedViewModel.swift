import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var followedCommunities: [CommunitySummary] = []
    @Published var selectedCommunity: CommunitySummary?
    @Published var isLoadingCommunities = false
    @Published var communitiesError: String?

    private let feedService: FeedServiceProtocol
    private let communityService: CommunityServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var nextCursor: String?
    private let pageSize = 20
    private let lastPostedCommunityKey = "lastPostedCommunityId"
    private let lastSelectedCommunityKey = "lastSelectedCommunityId"
    
    init(
        feedService: FeedServiceProtocol = FeedService(),
        communityService: CommunityServiceProtocol = CommunityService()
    ) {
        self.feedService = feedService
        self.communityService = communityService
    }

    func loadInitial() async {
        if followedCommunities.isEmpty {
            await loadFollowedCommunities()
        }
        await loadPosts(reset: true)
    }

    func loadFollowedCommunities() async {
        guard !isLoadingCommunities else { return }
        isLoadingCommunities = true
        communitiesError = nil
        defer { isLoadingCommunities = false }

        do {
            let page = try await communityService.fetchFollowedCommunities(limit: 50, cursor: nil)
            followedCommunities = page.items
            if let selected = selectedCommunity,
               followedCommunities.contains(where: { $0.id == selected.id }) {
                selectedCommunity = selected
            } else {
                selectedCommunity = nil
            }
            updateLastSelectedCommunityId()
        } catch {
            communitiesError = error.localizedDescription
            followedCommunities = []
            selectedCommunity = nil
        }
    }

    func selectCommunity(_ community: CommunitySummary) async {
        guard selectedCommunity?.id != community.id else { return }
        selectedCommunity = community
        updateLastSelectedCommunityId()
        await loadPosts(reset: true)
    }

    func selectAllCommunities() async {
        guard selectedCommunity != nil else { return }
        selectedCommunity = nil
        await loadPosts(reset: true)
    }

    var lastPostedCommunityId: Int? {
        get {
            let stored = UserDefaults.standard.integer(forKey: lastPostedCommunityKey)
            return stored == 0 ? nil : stored
        }
        set {
            UserDefaults.standard.set(newValue ?? 0, forKey: lastPostedCommunityKey)
        }
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
            let page = try await feedService.fetchFeed(
                limit: pageSize,
                cursor: reset ? nil : nextCursor,
                communityId: selectedCommunity?.id
            )
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
    
    func createPost(content: String, isAnonymous: Bool = false, communityId: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let newPost = try await feedService.createPost(
                content: content,
                isAnonymous: isAnonymous,
                communityId: communityId
            )
            posts.insert(newPost, at: 0)
            lastPostedCommunityId = communityId
            UserDefaults.standard.set(communityId, forKey: lastSelectedCommunityKey)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private extension FeedViewModel {
    func updateLastSelectedCommunityId() {
        if let selectedId = selectedCommunity?.id {
            UserDefaults.standard.set(selectedId, forKey: lastSelectedCommunityKey)
            return
        }
        let stored = UserDefaults.standard.integer(forKey: lastSelectedCommunityKey)
        if stored == 0, let fallbackId = followedCommunities.first?.id {
            UserDefaults.standard.set(fallbackId, forKey: lastSelectedCommunityKey)
        }
    }
}
