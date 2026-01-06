import Foundation

@MainActor
final class CommunityProfileViewModel: ObservableObject {
    @Published private(set) var community: CommunityProfileData
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var followErrorMessage: String?
    @Published var verification: CommunityVerification?
    @Published var isLoadingVerification = false
    @Published var verificationError: String?
    @Published var isFollowActionInFlight = false

    private let feedService: FeedServiceProtocol
    private let communityService: CommunityServiceProtocol
    private let verificationService: CommunityVerificationServiceProtocol
    private var nextCursor: String?
    private let pageSize = 20

    init(
        community: CommunityProfileData,
        feedService: FeedServiceProtocol = FeedService(),
        communityService: CommunityServiceProtocol = CommunityService(),
        verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()
    ) {
        self.community = community
        self.feedService = feedService
        self.communityService = communityService
        self.verificationService = verificationService
    }

    func loadIfNeeded() async {
        if posts.isEmpty {
            await loadPosts(reset: true)
        }
        await loadVerification()
    }

    func refresh() async {
        await loadPosts(reset: true)
        await loadVerification()
    }

    func loadMoreIfNeeded(currentPost: Post) async {
        guard let last = posts.last, last.id == currentPost.id else { return }
        await loadPosts(reset: false)
    }

    func toggleFollow() async {
        guard !isFollowActionInFlight else { return }
        isFollowActionInFlight = true
        followErrorMessage = nil
        let wasFollowing = community.isFollowing
        let delta = wasFollowing ? -1 : 1
        updateCommunity { community in
            community.isFollowing.toggle()
            community.memberCount = max(community.memberCount + delta, 0)
        }
        do {
            if wasFollowing {
                try await communityService.unfollowCommunity(id: community.id)
            } else {
                try await communityService.followCommunity(id: community.id)
            }
        } catch {
            updateCommunity { community in
                community.isFollowing = wasFollowing
                community.memberCount = max(community.memberCount - delta, 0)
            }
            followErrorMessage = followErrorMessage(from: error, wasFollowing: wasFollowing)
        }
        isFollowActionInFlight = false
    }

    func loadVerification() async {
        guard community.kind != .specialization else {
            verification = nil
            verificationError = nil
            return
        }
        guard !isLoadingVerification else { return }
        isLoadingVerification = true
        defer { isLoadingVerification = false }
        verificationError = nil
        do {
            let items = try await verificationService.fetchCommunityVerifications()
            verification = items.first(where: { $0.communityId == community.id })
        } catch {
            verification = nil
            verificationError = error.localizedDescription
        }
    }

    private func loadPosts(reset: Bool) async {
        if reset {
            guard !isLoading else { return }
            isLoading = true
        } else {
            guard !isLoadingMore, nextCursor != nil else { return }
            isLoadingMore = true
        }
        errorMessage = nil
        if reset { nextCursor = nil }

        do {
            let page = try await feedService.fetchFeed(
                limit: pageSize,
                cursor: reset ? nil : nextCursor,
                communityId: community.id,
                mode: .forYou
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

    private func updateCommunity(_ update: (inout CommunityProfileData) -> Void) {
        var next = community
        update(&next)
        community = next
    }

    private func followErrorMessage(from error: Error, wasFollowing: Bool) -> String {
        if !wasFollowing {
            return specializationFollowErrorMessage(from: error)
        }
        return "Couldn't unfollow community. \(error.localizedDescription)"
    }

    private func specializationFollowErrorMessage(from error: Error) -> String {
        guard case let APIError.apiError(_, apiError, message) = error else {
            return "Couldn't follow community. \(error.localizedDescription)"
        }

        let label = community.specializationLabel ?? "Specialization"
        switch apiError {
        case "specialization_limit":
            return specializationMessage(message, fallback: "You can only join 2 \(label.lowercased()) communities.", label: label)
        case "specialization_cooldown":
            return specializationMessage(message, fallback: "You can change your \(label.lowercased()) communities every 6 months.", label: label)
        default:
            return "Couldn't follow community. \(message ?? apiError)"
        }
    }

    private func specializationMessage(_ message: String?, fallback: String, label: String) -> String {
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return "\(trimmed) (\(label))"
        }
        return "\(fallback) (\(label))"
    }
}
