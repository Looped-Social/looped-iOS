import Foundation
import Combine

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
    @Published var isJoinActionInFlight = false
    @Published var isLoadingDetails = false

    private let feedService: FeedServiceProtocol
    private let communityService: CommunityServiceProtocol
    private let verificationService: CommunityVerificationServiceProtocol
    private var nextCursor: String?
    private let pageSize = 20
    private var hasLoadedDetails = false
    private var cancellables = Set<AnyCancellable>()

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
        NotificationCenter.default.publisher(for: .contentPreferencesChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshPostsForContentPreferencesChange() }
            }
            .store(in: &cancellables)
    }

    private func refreshPostsForContentPreferencesChange() async {
        await loadPosts(reset: true)
    }

    func loadIfNeeded() async {
        await loadCommunityDetails()
        if posts.isEmpty {
            await loadPosts(reset: true)
        }
        await loadVerification()
    }

    func refresh() async {
        await loadCommunityDetails(force: true)
        await loadPosts(reset: true)
        await loadVerification()
    }

    func loadMoreIfNeeded(currentPost: Post) async {
        guard let last = posts.last, last.id == currentPost.id else { return }
        await loadPosts(reset: false)
    }

    func toggleFollow() async {
        guard !isFollowActionInFlight else { return }
        guard !isJoinActionInFlight else { return }
        isFollowActionInFlight = true
        followErrorMessage = nil
        let isSpecialization = community.kind == .specialization
        let wasFollowing = community.isFollowing
        updateCommunity { community in
            community.isFollowing.toggle()
        }
        do {
            if wasFollowing {
                if isSpecialization {
                    try await communityService.unfollowSpecialization(id: community.id)
                } else {
                    try await communityService.unfollowCommunity(id: community.id)
                }
            } else {
                if isSpecialization {
                    try await communityService.followSpecialization(id: community.id)
                } else {
                    try await communityService.followCommunity(id: community.id)
                }
            }
        } catch {
            updateCommunity { community in
                community.isFollowing = wasFollowing
            }
            followErrorMessage = followErrorMessage(from: error, wasFollowing: wasFollowing)
        }
        isFollowActionInFlight = false
    }

    func toggleJoin() async {
        guard community.kind == .specialization else { return }
        guard !isJoinActionInFlight else { return }
        guard !isFollowActionInFlight else { return }
        isJoinActionInFlight = true
        followErrorMessage = nil

        let wasJoined = community.isJoined
        let wasFollowing = community.isFollowing

        updateCommunity { community in
            community.isJoined.toggle()
            if !wasJoined {
                community.isFollowing = true
            }
        }

        do {
            if wasJoined {
                try await communityService.unjoinSpecialization(id: community.id)
            } else {
                try await communityService.joinSpecialization(id: community.id)
            }
            await loadCommunityDetails(force: true)
        } catch {
            updateCommunity { community in
                community.isJoined = wasJoined
                community.isFollowing = wasFollowing
            }
            followErrorMessage = joinErrorMessage(from: error, wasJoined: wasJoined)
        }

        isJoinActionInFlight = false
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

    func loadCommunityDetails(force: Bool = false) async {
        guard force || !hasLoadedDetails else { return }
        guard !isLoadingDetails else { return }
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        do {
            let details = try await communityService.fetchCommunityDetails(communityId: community.id)
            hasLoadedDetails = true
            var merged = details
            let trimmed = (merged.imageUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                merged.imageUrl = community.imageUrl
            }
            community = merged
        } catch {
            // Keep placeholders if details fetch fails.
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
        if community.kind == .specialization {
            return specializationFollowErrorMessage(from: error, wasFollowing: wasFollowing)
        }
        if !wasFollowing {
            return "Couldn't follow community. \(error.localizedDescription)"
        }
        return "Couldn't unfollow community. \(error.localizedDescription)"
    }

    private func specializationFollowErrorMessage(from error: Error, wasFollowing: Bool) -> String {
        guard case let APIError.apiError(_, apiError, message) = error else {
            let verb = wasFollowing ? "unfollow" : "follow"
            return "Couldn't \(verb) specialization. \(error.localizedDescription)"
        }

        let verb = wasFollowing ? "unfollow" : "follow"
        return "Couldn't \(verb) specialization. \(message ?? apiError)"
    }

    private func joinErrorMessage(from error: Error, wasJoined: Bool) -> String {
        guard case let APIError.apiError(_, apiError, message) = error else {
            let verb = wasJoined ? "leave" : "join"
            return "Couldn't \(verb) specialization. \(error.localizedDescription)"
        }

        let label = community.specializationLabel ?? "Specialization"
        switch apiError {
        case "specialization_join_limit":
            return specializationMessage(
                message,
                fallback: "You can only join up to 2 \(label.lowercased()) communities.",
                label: label
            )
        case "specialization_join_cooldown":
            return specializationMessage(
                message,
                fallback: "You must wait 6 months before changing \(label.lowercased()) communities.",
                label: label
            )
        default:
            let verb = wasJoined ? "leave" : "join"
            return "Couldn't \(verb) specialization. \(message ?? apiError)"
        }
    }

    private func specializationMessage(_ message: String?, fallback: String, label: String) -> String {
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return "\(trimmed) (\(label))" }
        return "\(fallback) (\(label))"
    }
}
