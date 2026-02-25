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
    @Published var peopleRecommendationsRail: PeopleRecommendationRailPage?
    @Published var isLoadingPeopleRecommendations = false
    @Published private var connectingRecommendationUserIds: Set<Int> = []
    @Published private var connectedRecommendationUserIds: Set<Int> = []

    private let feedService: FeedServiceProtocol
    private let communityService: CommunityServiceProtocol
    private let verificationService: CommunityVerificationServiceProtocol
    private let peopleRecommendationService: PeopleRecommendationServiceProtocol
    private let userService: UserServiceProtocol
    private let followStateStore: FollowStateStore
    private var nextCursor: String?
    private let pageSize = 20
    private var hasLoadedDetails = false
    private var hasLoadedPeopleRecommendations = false
    private var isLoadingJoinLimit = false
    private var cancellables = Set<AnyCancellable>()

    init(
        community: CommunityProfileData,
        feedService: FeedServiceProtocol = FeedService(),
        communityService: CommunityServiceProtocol = CommunityService(),
        verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService(),
        peopleRecommendationService: PeopleRecommendationServiceProtocol = PeopleRecommendationService(),
        userService: UserServiceProtocol = UserService(),
        followStateStore: FollowStateStore? = nil
    ) {
        self.community = community
        self.feedService = feedService
        self.communityService = communityService
        self.verificationService = verificationService
        self.peopleRecommendationService = peopleRecommendationService
        self.userService = userService
        self.followStateStore = followStateStore ?? .shared
        NotificationCenter.default.publisher(for: .contentPreferencesChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshPostsForContentPreferencesChange() }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .communityStateChanged)
            .sink { [weak self] (notification: Foundation.Notification) in
                guard let self else { return }
                Task { await self.handleCommunityStateChanged(notification) }
            }
            .store(in: &cancellables)
        self.followStateStore.$followingUserIds
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncConnectedRecommendationUserIds()
            }
            .store(in: &cancellables)
    }

    private func refreshPostsForContentPreferencesChange() async {
        await loadPosts(reset: true)
    }

    private func handleCommunityStateChanged(_ notification: Foundation.Notification) async {
        let changedCommunityId = notification.userInfo?[LoopedNotificationUserInfoKey.communityId] as? Int

        if community.kind == .specialization {
            await loadSpecializationJoinLimit(force: true)
            if changedCommunityId == community.id {
                await loadCommunityDetails(force: true)
            }
            return
        }

        guard let changedCommunityId, changedCommunityId == community.id else { return }
        await loadCommunityDetails(force: true)
        await loadVerification()
    }

    func loadIfNeeded() async {
        await loadCommunityDetails()
        if posts.isEmpty {
            await loadPosts(reset: true)
        }
        await loadPeopleRecommendations()
        await loadSpecializationJoinLimit()
        await loadVerification()
    }

    func refresh() async {
        await loadCommunityDetails(force: true)
        await loadPosts(reset: true)
        await loadPeopleRecommendations(force: true)
        await loadSpecializationJoinLimit(force: true)
        await loadVerification()
    }

    func loadMoreIfNeeded(currentPost: Post) async {
        guard normalizedCursor(nextCursor) != nil else { return }
        guard let lastPost = posts.last else { return }
        guard currentPost.id == lastPost.id else { return }
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
            NotificationCenter.default.post(
                name: .communityStateChanged,
                object: nil,
                userInfo: [LoopedNotificationUserInfoKey.communityId: community.id]
            )
            if !wasFollowing {
                LoopedHaptics.success()
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
            await loadSpecializationJoinLimit(force: true)
            NotificationCenter.default.post(
                name: .communityStateChanged,
                object: nil,
                userInfo: [LoopedNotificationUserInfoKey.communityId: community.id]
            )
        } catch {
            if case let APIError.apiError(_, apiError, _) = error,
               apiError == "specialization_verification_required" {
                await loadSpecializationJoinLimit(force: true)
                await loadCommunityDetails(force: true)
            }
            updateCommunity { community in
                community.isJoined = wasJoined
                community.isFollowing = wasFollowing
            }
            followErrorMessage = joinErrorMessage(from: error, wasJoined: wasJoined)
        }

        isJoinActionInFlight = false
    }

    func loadSpecializationJoinLimit(force: Bool = false) async {
        guard community.kind == .specialization else { return }
        guard !isLoadingJoinLimit else { return }

        let specializationType = community.specializationType
        guard specializationType != .unknown else { return }

        isLoadingJoinLimit = true
        defer { isLoadingJoinLimit = false }

        do {
            let limits = try await communityService.fetchSpecializationJoinLimits(type: specializationType)
            if let limit = limits.first(where: { $0.specializationType == specializationType }) ?? limits.first {
                updateCommunity { community in
                    community.joinLimit = limit
                }
            }
        } catch {
            // Ignore: join-limit preflight shouldn't block the UI.
        }
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
            let fallback = community
            let details = try await communityService.fetchCommunityDetailsDTO(communityId: fallback.id, kind: fallback.kind)
            hasLoadedDetails = true
            community = CommunityProfileData(details: details, fallback: fallback)
        } catch {
            // Keep placeholders if details fetch fails.
        }
    }

    private func loadPosts(reset: Bool) async {
        let requestCursor = reset ? nil : normalizedCursor(nextCursor)
        if reset {
            guard !isLoading else { return }
            isLoading = true
        } else {
            guard !isLoadingMore, requestCursor != nil else { return }
            isLoadingMore = true
        }
        errorMessage = nil
        if reset { nextCursor = nil }

        do {
            let page = try await feedService.fetchFeed(
                limit: pageSize,
                cursor: requestCursor,
                communityId: community.id,
                mode: .forYou
            )
            let responseCursor = normalizedCursor(page.nextCursor)
            if reset {
                posts = deduplicatedPosts(page.posts)
                nextCursor = responseCursor
            } else {
                let merged = deduplicatedPosts(posts + page.posts)
                let addedCount = merged.count - posts.count
                if addedCount > 0 {
                    posts = merged
                }
                let cursorDidAdvance = responseCursor != requestCursor
                if addedCount == 0 || !cursorDidAdvance || page.posts.isEmpty {
                    nextCursor = nil
                } else {
                    nextCursor = responseCursor
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        if reset {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }

    func loadPeopleRecommendations(force: Bool = false) async {
        guard force || !hasLoadedPeopleRecommendations else { return }
        guard !isLoadingPeopleRecommendations else { return }

        isLoadingPeopleRecommendations = true
        defer {
            isLoadingPeopleRecommendations = false
            hasLoadedPeopleRecommendations = true
        }

        do {
            let bundle = try await peopleRecommendationService.fetchRails(
                surface: .search,
                communityId: community.id,
                rails: [.community],
                limitPerRail: 8
            )
            peopleRecommendationsRail = bundle.rails.first(where: { !$0.items.isEmpty })
            syncConnectedRecommendationUserIds()
        } catch {
            peopleRecommendationsRail = nil
        }
    }

    func canConnect(toRecommendation item: PeopleRecommendationItem) -> Bool {
        item.actions.canConnect && !connectedRecommendationUserIds.contains(item.user.id)
    }

    func isConnectingRecommendationUser(_ userId: Int) -> Bool {
        connectingRecommendationUserIds.contains(userId)
    }

    func connectRecommendedUser(_ item: PeopleRecommendationItem) async {
        guard canConnect(toRecommendation: item) else { return }
        guard !connectingRecommendationUserIds.contains(item.user.id) else { return }

        connectingRecommendationUserIds.insert(item.user.id)
        defer { connectingRecommendationUserIds.remove(item.user.id) }

        do {
            let result = try await userService.followUser(
                userId: item.user.id,
                asAnonymousActor: false,
                communityId: nil
            )
            connectedRecommendationUserIds.insert(item.user.id)
            followStateStore.setFollowing(result.following, userId: item.user.id)
            await sendRecommendationFeedback(type: .connectRequestSent, for: item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func hideRecommendation(_ item: PeopleRecommendationItem) {
        removeRecommendationCandidate(userId: item.user.id)
        Task {
            await sendRecommendationFeedback(type: .hide, for: item)
        }
    }

    func lessLikeThisRecommendation(_ item: PeopleRecommendationItem) {
        removeRecommendationCandidate(userId: item.user.id)
        Task {
            await sendRecommendationFeedback(type: .lessLikeThis, for: item)
        }
    }

    func didTapRecommendationProfile(_ item: PeopleRecommendationItem) {
        Task {
            await sendRecommendationFeedback(type: .profileOpen, for: item)
        }
    }

    func didAppearRecommendation(_ item: PeopleRecommendationItem) {
        _ = item
    }

    func didDisappearRecommendation(_ item: PeopleRecommendationItem) {
        _ = item
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

    private func deduplicatedPosts(_ input: [Post]) -> [Post] {
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

    private func normalizedCursor(_ cursor: String?) -> String? {
        guard let trimmed = cursor?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func removeRecommendationCandidate(userId: Int) {
        guard var rail = peopleRecommendationsRail else { return }
        rail.items.removeAll(where: { $0.user.id == userId })
        peopleRecommendationsRail = rail
        connectedRecommendationUserIds.remove(userId)
    }

    private func syncConnectedRecommendationUserIds() {
        let recommendationUserIds = Set(peopleRecommendationsRail?.items.map(\.user.id) ?? [])
        connectedRecommendationUserIds = recommendationUserIds.intersection(followStateStore.followingUserIds)
    }

    private func sendRecommendationFeedback(
        type: PeopleRecommendationFeedbackType,
        for item: PeopleRecommendationItem
    ) async {
        let event = PeopleRecommendationFeedbackEvent(
            type: type,
            recommendationId: item.recommendationId,
            trackingToken: item.tracking.token,
            position: item.tracking.position
        )
        _ = try? await peopleRecommendationService.sendFeedback(events: [event])
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
        case "specialization_verification_required":
            let required = community.joinLimit?.requiredVerificationKind?.rawValue ?? "company or school"
            return specializationMessage(
                message,
                fallback: "Verify your \(required) before joining \(label.lowercased()) communities.",
                label: label
            )
        case "specialization_join_limit":
            let limit = max(1, community.joinLimit?.limit ?? 2)
            return specializationMessage(
                message,
                fallback: "You can only join up to \(limit) \(label.lowercased()) communities.",
                label: label
            )
        case "specialization_join_cooldown":
            let months = max(1, community.joinLimit?.cooldownMonths ?? 6)
            return specializationMessage(
                message,
                fallback: "You must wait \(months) months before changing \(label.lowercased()) communities.",
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
