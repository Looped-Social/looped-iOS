import Foundation
import Combine
import UIKit

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
    @Published var isCommunitySearchActive: Bool = false
    @Published var communitySearchQuery: String = ""
    @Published var communitySearchResults: [CommunitySearchResult] = []
    @Published var isCommunitySearchLoading: Bool = false
    @Published var communitySearchError: String?
    @Published private(set) var recentFeedCommunity: CommunitySummary?

    private let feedService: FeedServiceProtocol
    private let communityService: CommunityServiceProtocol
    private let mediaService: MediaServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var nextCursor: String?
    private var communitiesNextCursor: String?
    private let pageSize = 20
    private let communityPageSize = 50
    private let lastPostedCommunityKey = "lastPostedCommunityId"
    private let lastSelectedCommunityKey = "lastSelectedCommunityId"
    private let feedActiveCommunityKey = "feedActiveCommunityId"
    private let feedRecentCommunityIdKey = "feedRecentCommunityId"
    private let feedRecentCommunityNameKey = "feedRecentCommunityName"
    private let feedRecentCommunityKindKey = "feedRecentCommunityKind"
    private let feedRecentCommunityMemberCountKey = "feedRecentCommunityMemberCount"
    private var lastToastAt: Date?
    private var communitySearchTask: Task<Void, Never>?
    
    init(
        feedService: FeedServiceProtocol = FeedService(),
        communityService: CommunityServiceProtocol = CommunityService(),
        mediaService: MediaServiceProtocol = MediaService()
    ) {
        self.feedService = feedService
        self.communityService = communityService
        self.mediaService = mediaService
        restoreFeedFilterState()
        NotificationCenter.default.publisher(for: .contentPreferencesChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshPosts() }
            }
            .store(in: &cancellables)
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
                if let recent = recentFeedCommunity,
                   let matched = followedCommunities.first(where: { $0.id == recent.id }) {
                    recentFeedCommunity = matched
                    persistRecentFeedCommunity(matched)
                }
                if let selected = selectedCommunity,
                   let matched = followedCommunities.first(where: { $0.id == selected.id }) {
                    selectedCommunity = matched
                    persistRecentFeedCommunity(matched)
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
        recentFeedCommunity = community
        persistRecentFeedCommunity(community)
        persistActiveFeedCommunityId(community.id)
        updateLastSelectedCommunityId()
        resetNewPostsToast()
        await loadPosts(reset: true)
    }

    func selectAllCommunities() async {
        guard selectedCommunity != nil else { return }
        selectedCommunity = nil
        persistActiveFeedCommunityId(nil)
        resetNewPostsToast()
        await loadPosts(reset: true)
    }

    var feedFilterCommunities: [CommunitySummary] {
        Self.makeFeedFilterCommunities(followedCommunities: followedCommunities, recentFeedCommunity: recentFeedCommunity)
    }

    static func makeFeedFilterCommunities(
        followedCommunities: [CommunitySummary],
        recentFeedCommunity: CommunitySummary?
    ) -> [CommunitySummary] {
        var merged = followedCommunities
        guard let recentFeedCommunity else { return merged }
        merged.removeAll { $0.id == recentFeedCommunity.id }
        merged.insert(recentFeedCommunity, at: 0)
        return merged
    }

    func updateCommunitySearchQuery(_ query: String) {
        communitySearchQuery = query
        communitySearchError = nil
        communitySearchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            communitySearchResults = []
            isCommunitySearchLoading = false
            return
        }
        guard trimmed.count >= 2 else {
            communitySearchResults = []
            isCommunitySearchLoading = false
            return
        }

        communitySearchTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await performCommunitySearch(query: trimmed)
        }
    }

    func dismissCommunitySearch() {
        isCommunitySearchActive = false
        communitySearchTask?.cancel()
        communitySearchTask = nil
        communitySearchQuery = ""
        communitySearchResults = []
        communitySearchError = nil
        isCommunitySearchLoading = false
    }

    func selectCommunityFromSearchResult(_ result: CommunitySearchResult) async {
        let resolved = followedCommunities.first(where: { $0.id == result.id })
            ?? CommunitySummary(
                id: result.id,
                name: result.name,
                kind: result.kind,
                memberCount: result.memberCount,
                isPinned: false,
                sortOrder: nil,
                canPost: false
            )
        await selectCommunity(resolved)
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
            if post.userReaction == .like {
                let response = try await feedService.unlikePost(
                    postId: backendId,
                    communityId: post.communityId
                )
                if let index = posts.firstIndex(where: { $0.backendId == response.postId }) {
                    posts[index] = posts[index].updating(
                        reactionCount: response.likesCount,
                        userReaction: .some(nil),
                        updatedAt: Date()
                    )
                }
            } else {
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
    func createPost(
        content: String,
        isAnonymous: Bool = false,
        communityId: Int,
        media: [LocalMediaItem] = [],
        poll: PollDraft? = nil
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if let poll, !poll.isValid {
                errorMessage = "Your poll needs a question and at least 2 unique options."
                return false
            }
            if trimmedContent.isEmpty && media.isEmpty {
                if poll != nil {
                    // Polls can be created without post text.
                } else {
                    errorMessage = "Add text or attach a photo."
                    return false
                }
            }

            var uploadedAttachment: MediaAttachment?
            var mediaAssetId: Int?

            if let first = media.first {
                guard first.type == .image, let image = first.image else {
                    errorMessage = "Only images are supported right now."
                    return false
                }
                guard let payload = makeUploadPayload(from: image) else {
                    errorMessage = "We couldn't read that image. Try another one."
                    return false
                }
                let asset = try await mediaService.uploadImage(
                    data: payload.data,
                    mimeType: payload.mimeType,
                    width: payload.width,
                    height: payload.height
                )
                mediaAssetId = asset.id
                if let url = asset.cdnUrl, !url.isEmpty {
                    uploadedAttachment = MediaAttachment(type: .image, url: url, width: payload.width, height: payload.height)
                }
            }

            let newPost = try await feedService.createPost(
                content: trimmedContent,
                isAnonymous: isAnonymous,
                communityId: communityId,
                mediaAssetId: mediaAssetId,
                poll: poll
            )
            let resolvedPost: Post
            if let uploadedAttachment, (newPost.attachments?.isEmpty ?? true) {
                resolvedPost = newPost.updating(attachments: .some([uploadedAttachment]))
            } else {
                resolvedPost = newPost
            }

            posts.insert(resolvedPost, at: 0)
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
    func performCommunitySearch(query: String) async {
        isCommunitySearchLoading = true
        defer { isCommunitySearchLoading = false }

        do {
            let page = try await communityService.searchCommunities(
                query: query,
                limit: 25,
                cursor: nil,
                kind: nil
            )
            communitySearchResults = page.items
        } catch {
            communitySearchResults = []
            communitySearchError = error.localizedDescription
        }
    }

    func restoreFeedFilterState() {
        let recentId = UserDefaults.standard.integer(forKey: feedRecentCommunityIdKey)
        if recentId > 0 {
            let name = UserDefaults.standard.string(forKey: feedRecentCommunityNameKey) ?? "Community"
            let kindRaw = UserDefaults.standard.string(forKey: feedRecentCommunityKindKey) ?? ""
            let kind = CommunityKind(rawValue: kindRaw) ?? .unknown
            let memberCount = UserDefaults.standard.integer(forKey: feedRecentCommunityMemberCountKey)
            recentFeedCommunity = CommunitySummary(
                id: recentId,
                name: name,
                kind: kind,
                memberCount: memberCount,
                isPinned: false,
                sortOrder: nil,
                canPost: false
            )
        }

        let activeId = UserDefaults.standard.integer(forKey: feedActiveCommunityKey)
        if activeId > 0, let recentFeedCommunity, recentFeedCommunity.id == activeId {
            selectedCommunity = recentFeedCommunity
        } else {
            selectedCommunity = nil
        }
    }

    func persistActiveFeedCommunityId(_ id: Int?) {
        UserDefaults.standard.set(id ?? 0, forKey: feedActiveCommunityKey)
    }

    func persistRecentFeedCommunity(_ community: CommunitySummary) {
        UserDefaults.standard.set(community.id, forKey: feedRecentCommunityIdKey)
        UserDefaults.standard.set(community.name, forKey: feedRecentCommunityNameKey)
        UserDefaults.standard.set(community.kind.rawValue, forKey: feedRecentCommunityKindKey)
        UserDefaults.standard.set(community.memberCount, forKey: feedRecentCommunityMemberCountKey)
    }

    func makeUploadPayload(from image: UIImage) -> ImageUploadPayload? {
        let resized = resizedImageIfNeeded(image, maxDimension: 2048)
        let width = Int(resized.size.width * resized.scale)
        let height = Int(resized.size.height * resized.scale)

        if imageHasAlpha(resized), let pngData = resized.pngData() {
            return ImageUploadPayload(data: pngData, mimeType: "image/png", width: width, height: height)
        }

        if let jpegData = resized.jpegData(compressionQuality: 0.85) {
            return ImageUploadPayload(data: jpegData, mimeType: "image/jpeg", width: width, height: height)
        }

        return nil
    }

    func resizedImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let maxPixel = max(pixelWidth, pixelHeight)
        guard maxPixel > maxDimension, maxPixel > 0 else { return image }

        let scaleFactor = maxDimension / maxPixel
        let newSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}

private struct ImageUploadPayload {
    let data: Data
    let mimeType: String
    let width: Int
    let height: Int
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
