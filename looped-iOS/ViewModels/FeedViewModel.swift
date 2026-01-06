import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var feedMode: FeedMode = .forYou
    @Published var followedCommunities: [CommunitySummary] = []
    @Published var selectedCommunity: CommunitySummary?
    @Published var isLoadingCommunities = false
    @Published var isLoadingMoreCommunities = false
    @Published var communitiesError: String?
    @Published var newPostsToastCount: Int?

    private let feedService: FeedServiceProtocol
    private let communityService: CommunityServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var nextCursor: String?
    private var communitiesNextCursor: String?
    private let pageSize = 20
    private let communityPageSize = 50
    private let lastPostedCommunityKey = "lastPostedCommunityId"
    private let lastSelectedCommunityKey = "lastSelectedCommunityId"
    private var lastToastAt: Date?
    
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

    func loadFollowedCommunities(reset: Bool = true) async {
        if reset {
            guard !isLoadingCommunities else { return }
            isLoadingCommunities = true
            communitiesNextCursor = nil
        } else {
            guard !isLoadingMoreCommunities, communitiesNextCursor != nil else { return }
            isLoadingMoreCommunities = true
        }
        communitiesError = nil
        defer {
            if reset {
                isLoadingCommunities = false
            } else {
                isLoadingMoreCommunities = false
            }
        }

        do {
            let page = try await communityService.fetchFollowedCommunities(
                limit: communityPageSize,
                cursor: reset ? nil : communitiesNextCursor,
                order: .relevant
            )
            if reset {
                followedCommunities = page.items
                if let selected = selectedCommunity,
                   followedCommunities.contains(where: { $0.id == selected.id }) {
                    selectedCommunity = selected
                } else {
                    selectedCommunity = nil
                }
            } else {
                var seen = Set(followedCommunities.map { $0.id })
                let appended = page.items.filter { seen.insert($0.id).inserted }
                followedCommunities.append(contentsOf: appended)
            }
            communitiesNextCursor = page.nextCursor
            updateLastSelectedCommunityId()
        } catch {
            communitiesError = error.localizedDescription
            if reset {
                followedCommunities = []
                selectedCommunity = nil
            }
            communitiesNextCursor = nil
        }
    }

    func loadMoreFollowedCommunitiesIfNeeded(currentCommunity: CommunitySummary) async {
        guard let lastCommunity = followedCommunities.last,
              currentCommunity.id == lastCommunity.id else { return }
        await loadFollowedCommunities(reset: false)
    }

    func selectCommunity(_ community: CommunitySummary) async {
        guard selectedCommunity?.id != community.id else { return }
        selectedCommunity = community
        updateLastSelectedCommunityId()
        resetNewPostsToast()
        await loadPosts(reset: true)
    }

    func selectAllCommunities() async {
        guard selectedCommunity != nil else { return }
        selectedCommunity = nil
        resetNewPostsToast()
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
            newPostsToastCount = nil
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
                communityId: selectedCommunity?.id,
                mode: feedMode
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

    func selectFeedMode(_ mode: FeedMode) async {
        guard feedMode != mode else { return }
        feedMode = mode
        resetNewPostsToast()
        await loadPosts(reset: true)
    }
    
    func refreshPosts() async {
        await loadPosts(reset: true)
    }

    func checkForNewPosts(minCount: Int, cooldown: TimeInterval, isAtTop: Bool) async {
        guard !isLoading, !isLoadingMore else { return }
        guard let currentTop = posts.first else { return }

        do {
            let page = try await feedService.fetchFeed(
                limit: minCount,
                cursor: nil,
                communityId: selectedCommunity?.id,
                mode: feedMode
            )
            let newCount = countNewPosts(in: page.posts, comparedTo: currentTop)
            guard newCount > 0 else { return }

            if isAtTop {
                await loadPosts(reset: true)
                return
            }

            if let existing = newPostsToastCount {
                if newCount > existing {
                    newPostsToastCount = newCount
                }
                return
            }

            let now = Date()
            if let lastToastAt, now.timeIntervalSince(lastToastAt) < cooldown {
                return
            }

            guard newCount >= minCount else { return }
            newPostsToastCount = newCount
            lastToastAt = now
        } catch {
            return
        }
    }

    func dismissNewPostsToast() {
        newPostsToastCount = nil
    }

    func loadMoreIfNeeded(currentPost: Post) async {
        guard let lastPost = posts.last, currentPost.id == lastPost.id else { return }
        await loadPosts(reset: false)
    }
    
    func reactToPost(_ post: Post, reaction: ReactionType) async {
        guard let backendId = post.backendId else { return }
        do {
            let response = try await feedService.reactToPost(
                postId: backendId,
                communityId: post.communityId,
                reaction: reaction
            )
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

    func removePost(backendId: Int?) {
        guard let backendId else { return }
        posts.removeAll { $0.backendId == backendId }
    }

    func updatePost(_ updated: Post) {
        guard let backendId = updated.backendId else { return }
        if let index = posts.firstIndex(where: { $0.backendId == backendId }) {
            posts[index] = updated
        }
    }
    
    @discardableResult
    func createPost(content: String, isAnonymous: Bool = false, communityId: Int) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let newPost = try await feedService.createPost(
                content: content,
                isAnonymous: isAnonymous,
                communityId: communityId
            )
            posts.insert(newPost, at: 0)
            lastPostedCommunityId = communityId
            UserDefaults.standard.set(communityId, forKey: lastSelectedCommunityKey)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
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

    func resetNewPostsToast() {
        newPostsToastCount = nil
        lastToastAt = nil
    }

    func countNewPosts(in fetched: [Post], comparedTo currentTop: Post) -> Int {
        guard let fetchedTop = fetched.first else { return 0 }
        guard isNewer(fetchedTop, than: currentTop) else { return 0 }

        guard let currentBackendId = currentTop.backendId else {
            return fetched.count
        }

        for (index, post) in fetched.enumerated() {
            if post.backendId == currentBackendId {
                return index
            }
        }
        return fetched.count
    }

    func isNewer(_ post: Post, than anchor: Post) -> Bool {
        if post.createdAt > anchor.createdAt {
            return true
        }
        if post.createdAt == anchor.createdAt,
           let postId = post.backendId,
           let anchorId = anchor.backendId {
            return postId > anchorId
        }
        return false
    }
}
