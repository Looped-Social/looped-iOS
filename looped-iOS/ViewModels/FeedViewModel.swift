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
    @Published var showSkeleton = false
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
    @Published private(set) var recentFeedCommunities: [CommunitySummary] = []

    enum CreatePostResult: Equatable {
        case created
        case createdUnderReview
        case queuedForReview
        case failed
    }

    private let feedService: FeedServiceProtocol
    private let communityService: CommunityServiceProtocol
    private let mediaService: MediaServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var nextCursor: String?
    private var communitiesNextCursor: String?
    private let pageSize = 20
    private let communityPageSize = 50
    private var activeFeedRequestId = UUID()
    private var skeletonDelayTask: Task<Void, Never>?
    private let lastPostedCommunityKey = "lastPostedCommunityId"
    private let lastSelectedCommunityKey = "lastSelectedCommunityId"
    private let feedActiveCommunityKey = "feedActiveCommunityId"
    private let feedRecentCommunitiesKey = "feedRecentCommunities"
    private let feedRecentCommunityIdKey = "feedRecentCommunityId"
    private let feedRecentCommunityNameKey = "feedRecentCommunityName"
    private let feedRecentCommunityShortNameKey = "feedRecentCommunityShortName"
    private let feedRecentCommunityKindKey = "feedRecentCommunityKind"
    private let feedRecentCommunityMemberCountKey = "feedRecentCommunityMemberCount"
    private let maxRecentFeedCommunities = 12
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
        NotificationCenter.default.publisher(for: .communityStateChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.loadFollowedCommunities(reset: true) }
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
                if let selected = selectedCommunity,
                   let matched = followedCommunities.first(where: { $0.id == selected.id }) {
                    selectedCommunity = matched
                    bumpRecentCommunity(matched)
                }
                normalizeRecentCommunities(using: followedCommunities)
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
        bumpRecentCommunity(community)
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
        Self.makeFeedFilterCommunities(
            followedCommunities: followedCommunities,
            recentFeedCommunities: recentFeedCommunities
        )
    }

    static func makeFeedFilterCommunities(
        followedCommunities: [CommunitySummary],
        recentFeedCommunities: [CommunitySummary]
    ) -> [CommunitySummary] {
        var merged = followedCommunities
        guard !recentFeedCommunities.isEmpty else { return merged }

        var uniqueRecent: [CommunitySummary] = []
        uniqueRecent.reserveCapacity(min(recentFeedCommunities.count, 12))
        var seenRecentIds = Set<Int>()
        for community in recentFeedCommunities where seenRecentIds.insert(community.id).inserted {
            uniqueRecent.append(community)
        }

        let recentIds = Set(uniqueRecent.map(\.id))
        merged.removeAll { recentIds.contains($0.id) }
        merged.insert(contentsOf: uniqueRecent, at: 0)
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
                shortName: result.shortName,
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
    
    func loadPosts(reset: Bool = true, clearExistingPosts: Bool = false, force: Bool = false) async {
        let requestId = UUID()
        let contextId: UUID
        if reset {
            activeFeedRequestId = requestId
            contextId = requestId
        } else {
            contextId = activeFeedRequestId
        }
        if reset {
            if isLoading, !force { return }
            isLoading = true
            isLoadingMore = false
            newPostsToastCount = nil
            showSkeleton = false
            skeletonDelayTask?.cancel()
            skeletonDelayTask = nil
            if clearExistingPosts {
                posts = []
            }
            if posts.isEmpty {
                let delayContextId = contextId
                skeletonDelayTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    guard activeFeedRequestId == delayContextId else { return }
                    guard isLoading, posts.isEmpty else { return }
                    showSkeleton = true
                }
            }
        } else {
            if isLoadingMore || nextCursor == nil { return }
            isLoadingMore = true
        }
        errorMessage = nil
        if reset { nextCursor = nil }
        
        do {
            let requestedMode = feedMode
            let requestedCommunityId = selectedCommunity?.id
            let page = try await feedService.fetchFeed(
                limit: pageSize,
                cursor: reset ? nil : nextCursor,
                communityId: requestedCommunityId,
                mode: requestedMode
            )
            guard activeFeedRequestId == contextId else { return }
            guard requestedMode == feedMode, requestedCommunityId == selectedCommunity?.id else { return }
            if reset {
                posts = deduplicatedPosts(page.posts)
            } else {
                posts = deduplicatedPosts(posts + page.posts)
            }
            nextCursor = page.nextCursor
        } catch {
            guard activeFeedRequestId == contextId else { return }
            errorMessage = error.localizedDescription
        }
        
        if reset {
            if activeFeedRequestId == contextId {
                isLoading = false
                showSkeleton = false
                skeletonDelayTask?.cancel()
                skeletonDelayTask = nil
            }
        } else {
            if activeFeedRequestId == contextId {
                isLoadingMore = false
            }
        }
    }

    func selectFeedMode(_ mode: FeedMode) async {
        guard feedMode != mode else { return }
        feedMode = mode
        resetNewPostsToast()
        await loadPosts(reset: true, clearExistingPosts: true, force: true)
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
        let prefetchThreshold = 6
        guard nextCursor != nil else { return }
        guard !posts.isEmpty else { return }
        guard posts.suffix(prefetchThreshold).contains(where: { $0.id == currentPost.id }) else { return }
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
            if isNotFound(error) {
                removePost(backendId: backendId)
                errorMessage = "Content unavailable"
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func removePost(backendId: Int?) {
        guard let backendId else { return }
        posts.removeAll { $0.backendId == backendId }
    }

    func removePosts(authorBackendId: Int) {
        posts.removeAll { $0.authorBackendId == authorBackendId }
    }

    func removePosts(authorPrincipalId: Int) {
        posts.removeAll { $0.authorPrincipalId == authorPrincipalId }
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
        ,
        onStatus: ((ToastMessage) -> Void)? = nil
    ) async -> CreatePostResult {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if let poll, !poll.isValid {
                errorMessage = "Your poll needs a question and at least 2 unique options."
                return .failed
            }
            if trimmedContent.isEmpty && media.isEmpty {
                if poll != nil {
                    // Polls can be created without post text.
                } else {
                    errorMessage = "Add text or attach media."
                    return .failed
                }
            }

            var uploadedAttachments: [MediaAttachment] = []
            var mediaAssetIds: [Int] = []

            if !media.isEmpty {
                onStatus?(ToastMessage(text: "Uploading…", kind: .loading))
                let actor: MediaUploadActor = isAnonymous ? .anon : .user
                let videos = media.filter { $0.type == .video }
                let images = media.filter { $0.type == .image }
                let gifs = media.filter { $0.type == .gif }

                if !gifs.isEmpty {
                    errorMessage = "GIFs aren't supported yet."
                    return .failed
                }

                if let video = videos.first {
                    guard videos.count == 1, images.isEmpty else {
                        errorMessage = "Videos must be posted by themselves."
                        return .failed
                    }
                    guard let url = video.videoURL else {
                        errorMessage = "We couldn't read that video. Try another one."
                        return .failed
                    }
                    let mp4Url = try await VideoTranscoder.ensureMP4(at: url)
                    defer {
                        TemporaryMediaFile.deleteIfOwned(mp4Url)
                        TemporaryMediaFile.deleteIfOwned(url)
	                    }
	                    let metadata = await videoMetadata(url: mp4Url)
	                    var thumbnailMediaAssetId: Int?
	                    var thumbnailUrl: String?
	                    let resolvedThumbnailImage: UIImage?
	                    if let existing = video.image {
	                        resolvedThumbnailImage = existing
	                    } else {
	                        resolvedThumbnailImage = await makeVideoThumbnail(url: mp4Url)
	                    }
	                    if let resolvedThumbnailImage,
	                       let payload = FeedViewModel.makeUploadPayload(from: resolvedThumbnailImage) {
	                        do {
	                            let thumbnailAsset = try await mediaService.uploadImage(
	                                data: payload.data,
	                                mimeType: payload.mimeType,
	                                width: payload.width,
                                height: payload.height,
                                actor: actor
                            )
                            thumbnailMediaAssetId = thumbnailAsset.id
                            thumbnailUrl = thumbnailAsset.cdnUrl
                        } catch {
                            thumbnailMediaAssetId = nil
                            thumbnailUrl = nil
                        }
                    }
                    let asset = try await mediaService.uploadVideo(
                        fileURL: mp4Url,
                        mimeType: "video/mp4",
                        width: metadata.width,
                        height: metadata.height,
                        durationSeconds: metadata.durationSeconds,
                        actor: actor,
                        thumbnailMediaAssetId: thumbnailMediaAssetId
                    )
                    mediaAssetIds = [asset.id]
                    if let cdnUrl = asset.cdnUrl, !cdnUrl.isEmpty {
                        uploadedAttachments = [MediaAttachment(
                            id: "asset:\(asset.id)",
                            type: .video,
                            url: cdnUrl,
                            thumbnailUrl: thumbnailUrl,
                            width: metadata.width,
                            height: metadata.height,
                            duration: TimeInterval(metadata.durationSeconds)
                        )]
                    }
                } else if !images.isEmpty {
                    let selection = Array(images.prefix(4))
                    let result = try await uploadImages(selection, actor: actor, maxConcurrentUploads: 3)
                    mediaAssetIds = result.assetIds
                    uploadedAttachments = result.attachments
                }
            }

            if !mediaAssetIds.isEmpty, uploadedAttachments.count != mediaAssetIds.count {
                do {
                    let resolved = try await mediaService.resolvePublicMedia(ids: mediaAssetIds)
                    let byId = Dictionary(uniqueKeysWithValues: resolved.map { ($0.id, $0) })
                    let resolvedAttachments = mediaAssetIds.compactMap { id -> MediaAttachment? in
                        guard let asset = byId[id], let url = asset.cdnUrl, !url.isEmpty else { return nil }
                        let mimeType = asset.mimeType.trimmingCharacters(in: .whitespacesAndNewlines)
                        let isVideo = mimeType.lowercased().hasPrefix("video/") || asset.durationSeconds != nil
                        let type: MediaType = isVideo ? .video : .image
                        return MediaAttachment(id: "asset:\(asset.id)", type: type, url: url)
                    }
                    if !resolvedAttachments.isEmpty {
                        uploadedAttachments = resolvedAttachments
                    }
                } catch {
                    // Best-effort: keep whatever URLs we already have.
                }
            }

            if !media.isEmpty {
                onStatus?(ToastMessage(text: "Finalizing…", kind: .loading))
            }
            let newPost = try await feedService.createPost(
                content: trimmedContent,
                isAnonymous: isAnonymous,
                communityId: communityId,
                mediaAssetId: mediaAssetIds.first,
                mediaAssetIds: mediaAssetIds.isEmpty ? nil : mediaAssetIds,
                poll: poll
            )
            let resolvedPost: Post
            if !uploadedAttachments.isEmpty, (newPost.attachments?.isEmpty ?? true) {
                resolvedPost = newPost.updating(attachments: .some(uploadedAttachments))
            } else {
                resolvedPost = newPost
            }

            posts.insert(resolvedPost, at: 0)
            posts = deduplicatedPosts(posts)
            lastPostedCommunityId = communityId
            UserDefaults.standard.set(communityId, forKey: lastSelectedCommunityKey)
            return resolvedPost.isUnderReview ? .createdUnderReview : .created
        } catch {
            if isAnonymous,
               case let APIError.apiError(code, apiError, _) = error,
               code == 403,
               apiError == "content_under_review" {
                return .queuedForReview
            }
            if case let APIError.apiError(code, apiError, message) = error, code == 403 {
                switch apiError {
                case "community_not_verified":
                    errorMessage = "You must be verified in this community to post. Go to that community and tap Verify."
                case "specialization_not_joined":
                    errorMessage = "Join this major or field to post."
                case "community_banned":
                    errorMessage = message ?? "Posting is disabled in this community right now."
                case "user_not_verified":
                    errorMessage = "You must be verified before posting."
                case "verification_expired":
                    errorMessage = "Your verification expired. Verify again to post."
                case "user_not_provisioned":
                    errorMessage = "Finish setting up your account before posting."
                default:
                    errorMessage = message ?? apiError
                }
                return .failed
            }
            if case let APIError.apiError(code, apiError, message) = error, code == 404 {
                switch apiError {
                case "community_not_found":
                    errorMessage = "That community couldn't be found. Select another community and try again."
                default:
                    errorMessage = message ?? apiError
                }
                return .failed
            }
            if case let APIError.apiError(code, apiError, message) = error, code == 400 {
                switch apiError {
                case "idempotency_required":
                    errorMessage = "We couldn't post that right now. Please try again."
                default:
                    errorMessage = message ?? apiError
                }
                return .failed
            }
            if case let APIError.apiError(code, apiError, message) = error, code == 422 {
                switch apiError {
                case "community_required":
                    errorMessage = "Pick a community before posting."
                case "media_not_found":
                    errorMessage = "Couldn't find your uploaded media yet. Try again."
                case "media_invalid":
                    errorMessage = message ?? "That attachment isn't supported."
                case "media_too_many":
                    errorMessage = message ?? "Attach up to 4 photos or 1 video."
                case "content_required":
                    errorMessage = "Add a caption, media, or a poll."
                default:
                    errorMessage = message ?? apiError
                }
                return .failed
            }
            errorMessage = error.localizedDescription
            return .failed
        }
    }
}

private extension FeedViewModel {
    struct UnsafeSendable<T>: @unchecked Sendable {
        let value: T
        init(_ value: T) { self.value = value }
    }

    struct UploadedMediaResult {
        let assetIds: [Int]
        let attachments: [MediaAttachment]
    }

    enum FeedMediaUploadError: LocalizedError {
        case unreadableImage

        var errorDescription: String? {
            switch self {
            case .unreadableImage:
                return "We couldn't read that image. Try another one."
            }
        }
    }

    func uploadImages(
        _ items: [LocalMediaItem],
        actor: MediaUploadActor,
        maxConcurrentUploads: Int
    ) async throws -> UploadedMediaResult {
        guard !items.isEmpty else { return UploadedMediaResult(assetIds: [], attachments: []) }
        let unsafeMediaService = UnsafeSendable(mediaService)

        var indexedImages: [(index: Int, image: UnsafeSendable<UIImage>)] = []
        indexedImages.reserveCapacity(items.count)
        for (index, item) in items.enumerated() {
            guard let image = item.image else { throw FeedMediaUploadError.unreadableImage }
            indexedImages.append((index: index, image: UnsafeSendable(image)))
        }

        let resolvedConcurrency = min(max(maxConcurrentUploads, 1), indexedImages.count)

        var results: [(index: Int, asset: MediaAsset, attachment: MediaAttachment?)] = []
        results.reserveCapacity(indexedImages.count)

        try await withThrowingTaskGroup(of: (Int, MediaAsset, MediaAttachment?).self) { group in
            #if DEBUG
            let startedAt = Date()
            #endif
            var nextIndex = 0

            func enqueue(_ index: Int) {
                group.addTask { [unsafeMediaService] in
                    let entry = indexedImages[index]
                    guard let payload = autoreleasepool(invoking: { FeedViewModel.makeUploadPayload(from: entry.image.value) }) else {
                        throw FeedMediaUploadError.unreadableImage
                    }
                    #if DEBUG
                    print("Post image prepared index=\(entry.index) bytes=\(payload.data.count) mime=\(payload.mimeType) size=\(payload.width)x\(payload.height)")
                    #endif

                    let asset = try await unsafeMediaService.value.uploadImage(
                        data: payload.data,
                        mimeType: payload.mimeType,
                        width: payload.width,
                        height: payload.height,
                        actor: actor
                    )

                    let attachment = asset.cdnUrl.flatMap { url -> MediaAttachment? in
                        guard !url.isEmpty else { return nil }
                        return MediaAttachment(
                            id: "asset:\(asset.id)",
                            type: .image,
                            url: url,
                            width: payload.width,
                            height: payload.height
                        )
                    }
                    return (entry.index, asset, attachment)
                }
            }

            while nextIndex < resolvedConcurrency {
                enqueue(nextIndex)
                nextIndex += 1
            }

            while let completed = try await group.next() {
                results.append((completed.0, completed.1, completed.2))
                if nextIndex < indexedImages.count {
                    enqueue(nextIndex)
                    nextIndex += 1
                }
            }
            #if DEBUG
            print("Post images prepared+uploaded in \(Int(Date().timeIntervalSince(startedAt) * 1000))ms")
            #endif
        }

        let ordered = results.sorted { $0.index < $1.index }
        let assetIds = ordered.map { $0.asset.id }
        let attachments = ordered.compactMap(\.attachment)
        return UploadedMediaResult(assetIds: assetIds, attachments: attachments)
    }

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

    func deduplicatedPosts(_ input: [Post]) -> [Post] {
        var seen = Set<String>()
        var output: [Post] = []
        output.reserveCapacity(input.count)

        for post in input {
            let key: String
            if let backendId = post.backendId {
                key = "b:\(backendId)"
            } else {
                key = "u:\(post.id.uuidString)"
            }
            if seen.insert(key).inserted {
                output.append(post)
            }
        }

        return output
    }

    func restoreFeedFilterState() {
        if let data = UserDefaults.standard.data(forKey: feedRecentCommunitiesKey),
           let records = try? JSONDecoder().decode([RecentFeedCommunityRecord].self, from: data) {
            recentFeedCommunities = records.map { $0.toCommunitySummary() }
        }

        let recentId = UserDefaults.standard.integer(forKey: feedRecentCommunityIdKey)
        if recentFeedCommunities.isEmpty, recentId > 0 {
            let name = UserDefaults.standard.string(forKey: feedRecentCommunityNameKey) ?? "Community"
            let shortName = UserDefaults.standard.string(forKey: feedRecentCommunityShortNameKey)
            let kindRaw = UserDefaults.standard.string(forKey: feedRecentCommunityKindKey) ?? ""
            let kind = CommunityKind(rawValue: kindRaw) ?? .unknown
            let memberCount = UserDefaults.standard.integer(forKey: feedRecentCommunityMemberCountKey)
            recentFeedCommunities = [CommunitySummary(
                id: recentId,
                name: name,
                shortName: shortName,
                kind: kind,
                memberCount: memberCount,
                isPinned: false,
                sortOrder: nil,
                canPost: false
            )]
        }

        let activeId = UserDefaults.standard.integer(forKey: feedActiveCommunityKey)
        if activeId > 0, let index = recentFeedCommunities.firstIndex(where: { $0.id == activeId }) {
            let active = recentFeedCommunities.remove(at: index)
            recentFeedCommunities.insert(active, at: 0)
            selectedCommunity = active
            persistRecentFeedCommunities(recentFeedCommunities)
            persistRecentFeedCommunity(active)
            return
        }
        selectedCommunity = nil
    }

    func persistActiveFeedCommunityId(_ id: Int?) {
        UserDefaults.standard.set(id ?? 0, forKey: feedActiveCommunityKey)
    }

    func persistRecentFeedCommunity(_ community: CommunitySummary) {
        UserDefaults.standard.set(community.id, forKey: feedRecentCommunityIdKey)
        UserDefaults.standard.set(community.name, forKey: feedRecentCommunityNameKey)
        if let shortName = community.shortName?.trimmingCharacters(in: .whitespacesAndNewlines), !shortName.isEmpty {
            UserDefaults.standard.set(shortName, forKey: feedRecentCommunityShortNameKey)
        } else {
            UserDefaults.standard.removeObject(forKey: feedRecentCommunityShortNameKey)
        }
        UserDefaults.standard.set(community.kind.rawValue, forKey: feedRecentCommunityKindKey)
        UserDefaults.standard.set(community.memberCount, forKey: feedRecentCommunityMemberCountKey)
    }

    nonisolated static func makeUploadPayload(from image: UIImage) -> ImageUploadPayload? {
        guard let output = ImageUploadTranscoder.makeUploadPayload(from: image) else { return nil }
        return ImageUploadPayload(data: output.data, mimeType: output.mimeType, width: output.width, height: output.height)
    }

    func videoMetadata(url: URL) async -> (width: Int, height: Int, durationSeconds: Int) {
        await VideoAssetUtilities.basicMetadata(for: url)
    }

    func makeVideoThumbnail(url: URL) async -> UIImage? {
        await VideoAssetUtilities.thumbnail(for: url)
    }

}

private struct ImageUploadPayload: Sendable {
    let data: Data
    let mimeType: String
    let width: Int
    let height: Int
}

private extension FeedViewModel {
    struct RecentFeedCommunityRecord: Codable, Equatable {
        let id: Int
        let name: String
        let shortName: String?
        let kind: CommunityKind
        let memberCount: Int

        init(from community: CommunitySummary) {
            id = community.id
            name = community.name
            let trimmedShortName = community.shortName?.trimmingCharacters(in: .whitespacesAndNewlines)
            shortName = trimmedShortName?.isEmpty == false ? trimmedShortName : nil
            kind = community.kind
            memberCount = community.memberCount
        }

        func toCommunitySummary() -> CommunitySummary {
            CommunitySummary(
                id: id,
                name: name,
                shortName: shortName,
                kind: kind,
                memberCount: memberCount,
                isPinned: false,
                sortOrder: nil,
                canPost: false
            )
        }
    }

    func bumpRecentCommunity(_ community: CommunitySummary) {
        recentFeedCommunities.removeAll { $0.id == community.id }
        recentFeedCommunities.insert(community, at: 0)
        if recentFeedCommunities.count > maxRecentFeedCommunities {
            recentFeedCommunities = Array(recentFeedCommunities.prefix(maxRecentFeedCommunities))
        }
        persistRecentFeedCommunities(recentFeedCommunities)
        persistRecentFeedCommunity(community)
    }

    func normalizeRecentCommunities(using followed: [CommunitySummary]) {
        guard !recentFeedCommunities.isEmpty else { return }
        let normalized = recentFeedCommunities.map { recent in
            followed.first(where: { $0.id == recent.id }) ?? recent
        }
        guard normalized != recentFeedCommunities else { return }
        recentFeedCommunities = normalized
        persistRecentFeedCommunities(recentFeedCommunities)
        if let mostRecent = recentFeedCommunities.first {
            persistRecentFeedCommunity(mostRecent)
        }
    }

    func persistRecentFeedCommunities(_ communities: [CommunitySummary]) {
        let records = communities.map { RecentFeedCommunityRecord(from: $0) }
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: feedRecentCommunitiesKey)
    }

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

    func isNotFound(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let code):
                return code == 404
            case .apiError(let code, _, _):
                return code == 404
            default:
                return false
            }
        }
        return false
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
