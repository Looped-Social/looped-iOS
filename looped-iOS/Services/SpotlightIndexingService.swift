import Foundation

#if canImport(CoreSpotlight)
import CoreSpotlight
import UniformTypeIdentifiers
#endif

protocol SpotlightIndexingServiceProtocol {
    func reindexPosts(_ posts: [Post]) async
    func indexPosts(_ posts: [Post]) async
    func removePosts(withIds postIds: [Int]) async
    func removeAllPosts() async
}

enum SpotlightPostRoute {
    static let postsDomainIdentifier = "looped.posts"
    private static let postIdentifierPrefix = "post:"

    static func searchableIdentifier(forPostId postId: Int) -> String {
        "\(postIdentifierPrefix)\(postId)"
    }

    static func postId(fromSearchableIdentifier identifier: String) -> Int? {
        guard identifier.hasPrefix(postIdentifierPrefix) else { return nil }
        let rawValue = identifier.dropFirst(postIdentifierPrefix.count)
        guard let postId = Int(rawValue), postId > 0 else { return nil }
        return postId
    }

    static func deepLinkURL(forPostId postId: Int) -> URL? {
        guard postId > 0 else { return nil }
        return URL(string: "looped://post/\(postId)")
    }

    static func deepLinkURL(from userActivity: NSUserActivity) -> URL? {
        #if canImport(CoreSpotlight)
        guard userActivity.activityType == CSSearchableItemActionType else { return nil }
        guard let rawIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return nil
        }
        guard let postId = postId(fromSearchableIdentifier: rawIdentifier) else { return nil }
        return deepLinkURL(forPostId: postId)
        #else
        _ = userActivity
        return nil
        #endif
    }
}

final class SpotlightIndexingService: SpotlightIndexingServiceProtocol {
    #if canImport(CoreSpotlight)
    fileprivate struct SearchablePayload {
        let items: [CSSearchableItem]
        let nonIndexableIdentifiers: [String]
    }

    private let index: CSSearchableIndex
    private let maxIndexedPosts: Int
    private let resultExpirationSeconds: TimeInterval = 14 * 24 * 60 * 60
    #endif

    #if canImport(CoreSpotlight)
    init(maxIndexedPosts: Int = 80) {
        self.index = CSSearchableIndex.default()
        self.maxIndexedPosts = maxIndexedPosts
    }
    #else
    init() {}
    #endif

    func reindexPosts(_ posts: [Post]) async {
        #if canImport(CoreSpotlight)
        let payload = makePayload(from: posts, limit: maxIndexedPosts)
        if !payload.nonIndexableIdentifiers.isEmpty {
            await deletePosts(withIdentifiers: payload.nonIndexableIdentifiers)
        }
        guard !payload.items.isEmpty else { return }
        await indexPosts(payload.items)
        #else
        _ = posts
        #endif
    }

    func indexPosts(_ posts: [Post]) async {
        #if canImport(CoreSpotlight)
        let payload = makePayload(from: posts, limit: maxIndexedPosts)
        if !payload.nonIndexableIdentifiers.isEmpty {
            await deletePosts(withIdentifiers: payload.nonIndexableIdentifiers)
        }
        guard !payload.items.isEmpty else { return }
        await indexPosts(payload.items)
        #else
        _ = posts
        #endif
    }

    func removePosts(withIds postIds: [Int]) async {
        #if canImport(CoreSpotlight)
        let identifiers = Set(postIds.filter { $0 > 0 }.map(SpotlightPostRoute.searchableIdentifier(forPostId:)))
        guard !identifiers.isEmpty else { return }
        await deletePosts(withIdentifiers: Array(identifiers))
        #else
        _ = postIds
        #endif
    }

    func removeAllPosts() async {
        #if canImport(CoreSpotlight)
        await deletePostsDomain()
        #endif
    }
}

#if canImport(CoreSpotlight)
private extension SpotlightIndexingService {
    func makePayload(from posts: [Post], limit: Int) -> SearchablePayload {
        var seenPostIds = Set<Int>()
        var items: [CSSearchableItem] = []
        var nonIndexableIdentifiers: [String] = []
        items.reserveCapacity(min(posts.count, limit))
        nonIndexableIdentifiers.reserveCapacity(posts.count)

        for post in posts {
            guard let postId = post.backendId, postId > 0 else { continue }
            guard seenPostIds.insert(postId).inserted else { continue }

            if let item = makeSearchableItem(for: post, postId: postId) {
                if items.count < limit {
                    items.append(item)
                }
            } else {
                nonIndexableIdentifiers.append(SpotlightPostRoute.searchableIdentifier(forPostId: postId))
            }
        }

        return SearchablePayload(items: items, nonIndexableIdentifiers: nonIndexableIdentifiers)
    }

    func makeSearchableItem(for post: Post, postId: Int) -> CSSearchableItem? {
        guard !post.isUnderReview else { return nil }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .plainText)
        let communityLabel = cleanedCommunityName(for: post)
        if post.isAnonymous {
            attributeSet.title = communityLabel.map { "Anonymous post in \($0)" } ?? "Anonymous Looped post"
        } else {
            attributeSet.title = communityLabel.map { "Post in \($0)" } ?? "Looped post"
        }

        let summary = sanitizedSummary(from: post.content)
        if !summary.isEmpty {
            attributeSet.contentDescription = summary
        }

        var keywords = ["looped", "post"]
        if let communityLabel {
            keywords.append(communityLabel)
        }
        attributeSet.keywords = keywords

        if let deepLinkURL = SpotlightPostRoute.deepLinkURL(forPostId: postId) {
            attributeSet.contentURL = deepLinkURL
        }

        let item = CSSearchableItem(
            uniqueIdentifier: SpotlightPostRoute.searchableIdentifier(forPostId: postId),
            domainIdentifier: SpotlightPostRoute.postsDomainIdentifier,
            attributeSet: attributeSet
        )
        item.expirationDate = Date().addingTimeInterval(resultExpirationSeconds)
        return item
    }

    func cleanedCommunityName(for post: Post) -> String? {
        let value = post.communityShortName ?? post.communityName
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func sanitizedSummary(from raw: String) -> String {
        let trimmed = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let maxLength = 180
        guard trimmed.count > maxLength else { return trimmed }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return "\(trimmed[..<endIndex])..."
    }

    func indexPosts(_ items: [CSSearchableItem]) async {
        await withCheckedContinuation { continuation in
            index.indexSearchableItems(items) { error in
                SpotlightIndexingService.log(error: error, action: "index")
                continuation.resume()
            }
        }
    }

    func deletePosts(withIdentifiers identifiers: [String]) async {
        await withCheckedContinuation { continuation in
            index.deleteSearchableItems(withIdentifiers: identifiers) { error in
                SpotlightIndexingService.log(error: error, action: "delete_identifiers")
                continuation.resume()
            }
        }
    }

    func deletePostsDomain() async {
        await withCheckedContinuation { continuation in
            index.deleteSearchableItems(withDomainIdentifiers: [SpotlightPostRoute.postsDomainIdentifier]) { error in
                SpotlightIndexingService.log(error: error, action: "delete_domain")
                continuation.resume()
            }
        }
    }

    static func log(error: Error?, action: String) {
        #if DEBUG
        guard let error else { return }
        print("LOOPED_SPOTLIGHT action=\(action) error=\(error.localizedDescription)")
        #else
        _ = error
        _ = action
        #endif
    }
}
#endif
