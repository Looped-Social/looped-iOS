import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedTrendingIndex = 0
    @Published var trendingPosts: [TrendingPost] = []
    @Published var recommendedCommunities: [CommunitySearchResult] = []
    @Published var majors: [CommunitySearchResult] = []
    @Published var fields: [CommunitySearchResult] = []
    @Published var peopleRecommendationRails: [PeopleRecommendationRailPage] = []
    @Published var isLoadingSpecializations = false
    @Published var isLoadingMoreRecommendedCommunities = false
    @Published var isLoadingMoreMajors = false
    @Published var isLoadingMoreFields = false
    @Published var isLoadingPeopleRecommendations = false
    @Published var recommendationError: String?
    @Published var specializationsError: String?

    private let communityService: CommunityServiceProtocol
    private let feedService: FeedServiceProtocol
    private let discoveryService: DiscoveryServiceProtocol
    private let peopleRecommendationService: PeopleRecommendationServiceProtocol
    private let userService: UserServiceProtocol
    private let followStateStore: FollowStateStore
    private var recommendedCommunitiesNextCursor: String?
    private var majorsNextCursor: String?
    private var fieldsNextCursor: String?
    private let initialSpecializationsLimit = 24
    private let loadMoreSpecializationsLimit = 40
    private let recommendedCommunitiesLimit = 8
    private let trendingPostsLimit = 20
    private let recommendationRailPageLimit = 20
    private let recommendationFeedbackBatchThreshold = 20
    private let recommendationFeedbackFlushDelayNanoseconds: UInt64 = 2_000_000_000
    private var specializationIconsById: [Int: CommunityIcon] = [:]
    private var specializationIconsTask: Task<[Int: CommunityIcon], Never>?
    private var recommendationRailNextCursor: [PeopleRecommendationRail: String] = [:]
    private var recommendationRailHasMore: [PeopleRecommendationRail: Bool] = [:]
    @Published private var loadingRecommendationRails: Set<PeopleRecommendationRail> = []
    private var impressionedRecommendationIds: Set<String> = []
    private var visibleRecommendationIds: Set<String> = []
    private var pendingImpressionTasks: [String: Task<Void, Never>] = [:]
    private var queuedRecommendationFeedbackEvents: [PeopleRecommendationFeedbackEvent] = []
    private var feedbackFlushTask: Task<Void, Never>?
    private var isFlushingFeedback = false
    private var connectingRecommendationUserIds: Set<Int> = []
    private var connectedRecommendationUserIds: Set<Int> = []
    private var activeRecommendationCommunityId: Int?
    private var hasLoadedPeopleRecommendationsOnce = false
    private var cancellables: Set<AnyCancellable> = []
    private var lastObservedFollowingUserIds: Set<Int>

    var majorsHasMorePages: Bool { majorsNextCursor?.isEmpty == false }
    var fieldsHasMorePages: Bool { fieldsNextCursor?.isEmpty == false }

    init(
        communityService: CommunityServiceProtocol = CommunityService(),
        feedService: FeedServiceProtocol = FeedService(),
        discoveryService: DiscoveryServiceProtocol = DiscoveryService(),
        peopleRecommendationService: PeopleRecommendationServiceProtocol = PeopleRecommendationService(),
        userService: UserServiceProtocol = UserService(),
        followStateStore: FollowStateStore? = nil
    ) {
        self.communityService = communityService
        self.feedService = feedService
        self.discoveryService = discoveryService
        self.peopleRecommendationService = peopleRecommendationService
        self.userService = userService
        self.followStateStore = followStateStore ?? .shared
        self.lastObservedFollowingUserIds = self.followStateStore.followingUserIds

        self.followStateStore.$followingUserIds
            .receive(on: RunLoop.main)
            .sink { [weak self] followingUserIds in
                self?.handleFollowStateStoreUpdate(followingUserIds)
            }
            .store(in: &cancellables)

        Task {
            await loadSpecializations()
        }
        Task {
            await loadRecommendedCommunities()
        }
        Task {
            await loadTrendingPosts()
        }
        Task {
            await loadPeopleRecommendations()
        }
    }

    func loadSpecializations() async {
        isLoadingSpecializations = true
        defer { isLoadingSpecializations = false }

        majors = []
        fields = []
        majorsNextCursor = nil
        fieldsNextCursor = nil
        specializationsError = nil

        var firstError: Error?

        async let iconsById = loadSpecializationIconsById()

        do {
            let page = try await discoveryService.browseSpecializations(
                type: .major,
                limit: initialSpecializationsLimit,
                cursor: nil
            )
            majors = page.items
            majorsNextCursor = page.nextCursor
        } catch {
            firstError = firstError ?? error
        }

        do {
            let page = try await discoveryService.browseSpecializations(
                type: .field,
                limit: initialSpecializationsLimit,
                cursor: nil
            )
            fields = page.items
            fieldsNextCursor = page.nextCursor
        } catch {
            firstError = firstError ?? error
        }

        let resolvedIconsById = await iconsById
        majors = applyingSpecializationIcons(majors, iconsById: resolvedIconsById)
        fields = applyingSpecializationIcons(fields, iconsById: resolvedIconsById)
        recommendedCommunities = applyingSpecializationIcons(recommendedCommunities, iconsById: resolvedIconsById)

        if let firstError {
            specializationsError = firstError.localizedDescription
        }
    }

    func loadMoreMajors() async {
        guard !isLoadingMoreMajors else { return }
        guard let majorsNextCursor, !majorsNextCursor.isEmpty else { return }

        isLoadingMoreMajors = true
        defer { isLoadingMoreMajors = false }

        do {
            let page = try await discoveryService.browseSpecializations(
                type: .major,
                limit: loadMoreSpecializationsLimit,
                cursor: majorsNextCursor
            )
            self.majorsNextCursor = page.nextCursor
            let iconsById = await loadSpecializationIconsById()
            appendUnique(items: applyingSpecializationIcons(page.items, iconsById: iconsById), to: &majors)
        } catch {
            specializationsError = error.localizedDescription
        }
    }

    func loadMoreFields() async {
        guard !isLoadingMoreFields else { return }
        guard let fieldsNextCursor, !fieldsNextCursor.isEmpty else { return }

        isLoadingMoreFields = true
        defer { isLoadingMoreFields = false }

        do {
            let page = try await discoveryService.browseSpecializations(
                type: .field,
                limit: loadMoreSpecializationsLimit,
                cursor: fieldsNextCursor
            )
            self.fieldsNextCursor = page.nextCursor
            let iconsById = await loadSpecializationIconsById()
            appendUnique(items: applyingSpecializationIcons(page.items, iconsById: iconsById), to: &fields)
        } catch {
            specializationsError = error.localizedDescription
        }
    }

    private func appendUnique(items: [CommunitySearchResult], to existing: inout [CommunitySearchResult]) {
        var existingIds = Set(existing.map(\.id))
        for item in items where !existingIds.contains(item.id) {
            existing.append(item)
            existingIds.insert(item.id)
        }
    }

    func loadTrendingPosts() async {
        do {
            trendingPosts = try await feedService.fetchTrendingPosts(limit: trendingPostsLimit, communityId: nil)
            selectedTrendingIndex = 0
        } catch {
            trendingPosts = []
        }
    }

    func loadPeopleRecommendations(force: Bool = false) async {
        if isLoadingPeopleRecommendations {
            return
        }
        if hasLoadedPeopleRecommendationsOnce && !force {
            return
        }

        isLoadingPeopleRecommendations = true
        defer {
            isLoadingPeopleRecommendations = false
            hasLoadedPeopleRecommendationsOnce = true
        }
        recommendationError = nil
        let requestedRails: [PeopleRecommendationRail] = [.pymk]
        let currentUser: User?
        do {
            currentUser = try await userService.getCurrentUser()
        } catch {
            currentUser = nil
        }
        let resolvedCommunityId = currentUser?.displayCommunity?.id
        do {
            var requestedCommunityId = resolvedCommunityId
            var bundle = try await peopleRecommendationService.fetchRails(
                surface: .search,
                communityId: requestedCommunityId,
                rails: requestedRails,
                limitPerRail: 10
            )

            if requestedCommunityId == nil && !bundle.rails.contains(where: { !$0.items.isEmpty }) {
                if let fallbackCommunityId = try? await communityService.fetchFollowedCommunities(
                    limit: 1,
                    cursor: nil,
                    order: .relevant
                ).items.first?.id {
                    requestedCommunityId = fallbackCommunityId
                    bundle = try await peopleRecommendationService.fetchRails(
                        surface: .search,
                        communityId: requestedCommunityId,
                        rails: requestedRails,
                        limitPerRail: 10
                    )
                }
            }

            activeRecommendationCommunityId = requestedCommunityId
            peopleRecommendationRails = bundle.rails
            syncKnownFollowingRecommendationCandidates()
            recommendationRailNextCursor = [:]
            recommendationRailHasMore = [:]
            for railPage in bundle.rails {
                recommendationRailNextCursor[railPage.rail] = railPage.nextCursor
                recommendationRailHasMore[railPage.rail] = railPage.hasMore
            }
        } catch {
            activeRecommendationCommunityId = nil
            peopleRecommendationRails = []
            recommendationRailNextCursor = [:]
            recommendationRailHasMore = [:]
            recommendationError = error.localizedDescription
        }
    }

    func isLoadingMoreRecommendations(for rail: PeopleRecommendationRail) -> Bool {
        loadingRecommendationRails.contains(rail)
    }

    func loadMorePeopleRecommendations(for rail: PeopleRecommendationRail) async {
        guard !loadingRecommendationRails.contains(rail) else { return }
        guard recommendationRailHasMore[rail] == true else { return }
        guard let cursor = recommendationRailNextCursor[rail], !cursor.isEmpty else { return }

        loadingRecommendationRails.insert(rail)
        defer { loadingRecommendationRails.remove(rail) }

        do {
            let page = try await peopleRecommendationService.fetchRail(
                rail: rail,
                surface: .search,
                communityId: activeRecommendationCommunityId,
                limit: recommendationRailPageLimit,
                cursor: cursor
            )
            recommendationRailNextCursor[rail] = page.nextCursor
            recommendationRailHasMore[rail] = page.hasMore
            upsertRecommendationRailPage(page, appendItems: true)
        } catch {
            recommendationError = error.localizedDescription
        }
    }

    func canConnect(to item: PeopleRecommendationItem) -> Bool {
        item.actions.canConnect && !connectedRecommendationUserIds.contains(item.user.id)
    }

    func isConnectingRecommendationUser(_ userId: Int) -> Bool {
        connectingRecommendationUserIds.contains(userId)
    }

    func connectRecommendedUser(_ item: PeopleRecommendationItem) async {
        guard canConnect(to: item) else { return }
        let userId = item.user.id
        guard !connectingRecommendationUserIds.contains(userId) else { return }
        connectingRecommendationUserIds.insert(userId)
        defer { connectingRecommendationUserIds.remove(userId) }

        do {
            _ = try await userService.followUser(userId: userId, asAnonymousActor: false, communityId: nil)
            connectedRecommendationUserIds.insert(userId)
            followStateStore.setFollowing(true, userId: userId)
            queueRecommendationFeedback(
                .init(
                    type: .connectRequestSent,
                    recommendationId: item.recommendationId,
                    trackingToken: item.tracking.token,
                    position: item.tracking.position
                ),
                immediate: false
            )
        } catch {
            recommendationError = error.localizedDescription
        }
    }

    func didTapRecommendationProfile(_ item: PeopleRecommendationItem) {
        queueRecommendationFeedback(
            .init(
                type: .profileOpen,
                recommendationId: item.recommendationId,
                trackingToken: item.tracking.token,
                position: item.tracking.position
            ),
            immediate: false
        )
    }

    func didAppearRecommendation(_ item: PeopleRecommendationItem) {
        visibleRecommendationIds.insert(item.recommendationId)
        guard !impressionedRecommendationIds.contains(item.recommendationId) else { return }
        guard pendingImpressionTasks[item.recommendationId] == nil else { return }

        pendingImpressionTasks[item.recommendationId] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.commitImpressionIfStillVisible(for: item)
        }
    }

    func didDisappearRecommendation(_ item: PeopleRecommendationItem) {
        visibleRecommendationIds.remove(item.recommendationId)
        pendingImpressionTasks[item.recommendationId]?.cancel()
        pendingImpressionTasks[item.recommendationId] = nil
    }

    func hideRecommendation(_ item: PeopleRecommendationItem) {
        removeRecommendationCandidate(userId: item.user.id)
        queueRecommendationFeedback(
            .init(
                type: .hide,
                recommendationId: item.recommendationId,
                trackingToken: item.tracking.token,
                position: item.tracking.position
            ),
            immediate: true
        )
    }

    func lessLikeThisRecommendation(_ item: PeopleRecommendationItem) {
        removeRecommendationCandidate(userId: item.user.id)
        queueRecommendationFeedback(
            .init(
                type: .lessLikeThis,
                recommendationId: item.recommendationId,
                trackingToken: item.tracking.token,
                position: item.tracking.position
            ),
            immediate: true
        )
    }

    func loadRecommendedCommunities() async {
        do {
            isLoadingMoreRecommendedCommunities = false
            recommendedCommunitiesNextCursor = nil
            let page = try await communityService.fetchRecommendedCommunities(
                kind: nil,
                limit: recommendedCommunitiesLimit,
                cursor: nil
            )
            let iconsById = await loadSpecializationIconsById()
            recommendedCommunities = applyingSpecializationIcons(page.items, iconsById: iconsById)
            recommendedCommunitiesNextCursor = page.nextCursor
        } catch {
            recommendedCommunities = []
            recommendedCommunitiesNextCursor = nil
        }
    }

    func loadMoreRecommendedCommunities() async {
        guard !isLoadingMoreRecommendedCommunities else { return }
        guard let recommendedCommunitiesNextCursor, !recommendedCommunitiesNextCursor.isEmpty else { return }

        isLoadingMoreRecommendedCommunities = true
        defer { isLoadingMoreRecommendedCommunities = false }

        do {
            let page = try await communityService.fetchRecommendedCommunities(
                kind: nil,
                limit: recommendedCommunitiesLimit,
                cursor: recommendedCommunitiesNextCursor
            )
            self.recommendedCommunitiesNextCursor = page.nextCursor
            let iconsById = await loadSpecializationIconsById()
            appendUnique(items: applyingSpecializationIcons(page.items, iconsById: iconsById), to: &recommendedCommunities)
        } catch {
            // Keep the cursor so we can retry when the last card appears again.
        }
    }

    private func applyingSpecializationIcons(
        _ items: [CommunitySearchResult],
        iconsById: [Int: CommunityIcon]
    ) -> [CommunitySearchResult] {
        guard !items.isEmpty, !iconsById.isEmpty else { return items }
        return items.map { item in
            guard item.kind == .specialization else { return item }
            guard item.icon == nil else { return item }
            return item.withIcon(iconsById[item.id] ?? item.icon)
        }
    }

    private func loadSpecializationIconsById() async -> [Int: CommunityIcon] {
        if !specializationIconsById.isEmpty { return specializationIconsById }
        if let task = specializationIconsTask { return await task.value }

        let discoveryService = self.discoveryService
        let task = Task { () -> [Int: CommunityIcon] in
            async let majors = try? discoveryService.fetchMajorsIndex()
            async let fields = try? discoveryService.fetchFieldsIndex()
            let (majorItems, fieldItems) = await (majors, fields)

            var resolved: [Int: CommunityIcon] = [:]
            for item in (majorItems ?? []) {
                if let icon = item.icon {
                    resolved[item.id] = icon
                }
            }
            for item in (fieldItems ?? []) {
                if let icon = item.icon {
                    resolved[item.id] = icon
                }
            }
            return resolved
        }

        specializationIconsTask = task
        let resolved = await task.value
        specializationIconsTask = nil
        if !resolved.isEmpty {
            specializationIconsById = resolved
        }
        return resolved
    }

    private func commitImpressionIfStillVisible(for item: PeopleRecommendationItem) {
        pendingImpressionTasks[item.recommendationId] = nil
        guard visibleRecommendationIds.contains(item.recommendationId) else { return }
        guard !impressionedRecommendationIds.contains(item.recommendationId) else { return }
        impressionedRecommendationIds.insert(item.recommendationId)
        queueRecommendationFeedback(
            .init(
                type: .impression,
                recommendationId: item.recommendationId,
                trackingToken: item.tracking.token,
                position: item.tracking.position
            ),
            immediate: false
        )
    }

    private func queueRecommendationFeedback(
        _ event: PeopleRecommendationFeedbackEvent,
        immediate: Bool
    ) {
        queuedRecommendationFeedbackEvents.append(event)
        if immediate || queuedRecommendationFeedbackEvents.count >= recommendationFeedbackBatchThreshold {
            feedbackFlushTask?.cancel()
            feedbackFlushTask = nil
            Task { await flushRecommendationFeedback(force: true) }
            return
        }
        scheduleRecommendationFeedbackFlushIfNeeded()
    }

    private func scheduleRecommendationFeedbackFlushIfNeeded() {
        guard feedbackFlushTask == nil else { return }
        let flushDelay = recommendationFeedbackFlushDelayNanoseconds
        feedbackFlushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: flushDelay)
            await self?.flushRecommendationFeedback(force: true)
        }
    }

    private func flushRecommendationFeedback(force: Bool) async {
        guard !isFlushingFeedback else { return }
        guard !queuedRecommendationFeedbackEvents.isEmpty else { return }
        if !force && queuedRecommendationFeedbackEvents.count < recommendationFeedbackBatchThreshold {
            return
        }

        isFlushingFeedback = true
        defer { isFlushingFeedback = false }
        feedbackFlushTask?.cancel()
        feedbackFlushTask = nil

        while !queuedRecommendationFeedbackEvents.isEmpty {
            let batch = Array(queuedRecommendationFeedbackEvents.prefix(200))
            queuedRecommendationFeedbackEvents.removeFirst(batch.count)
            do {
                let response = try await peopleRecommendationService.sendFeedback(events: batch)
                if !response.suppressedCandidateIds.isEmpty {
                    for userId in response.suppressedCandidateIds {
                        removeRecommendationCandidate(userId: userId)
                    }
                }
            } catch {
                queuedRecommendationFeedbackEvents.insert(contentsOf: batch, at: 0)
                recommendationError = error.localizedDescription
                break
            }
        }
    }

    private func upsertRecommendationRailPage(
        _ page: PeopleRecommendationRailPage,
        appendItems: Bool
    ) {
        guard let existingIndex = peopleRecommendationRails.firstIndex(where: { $0.rail == page.rail }) else {
            peopleRecommendationRails.append(page)
            syncKnownFollowingRecommendationCandidates()
            return
        }

        if !appendItems {
            peopleRecommendationRails[existingIndex] = page
            syncKnownFollowingRecommendationCandidates()
            return
        }

        var existing = peopleRecommendationRails[existingIndex]
        var seenRecommendationIds = Set(existing.items.map(\.recommendationId))
        for item in page.items where !seenRecommendationIds.contains(item.recommendationId) {
            existing.items.append(item)
            seenRecommendationIds.insert(item.recommendationId)
        }

        let merged = PeopleRecommendationRailPage(
            requestId: page.requestId,
            rail: page.rail,
            title: page.title,
            items: existing.items,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore,
            degraded: page.degraded,
            community: page.community,
            experiment: page.experiment
        )
        peopleRecommendationRails[existingIndex] = merged
        syncKnownFollowingRecommendationCandidates()
    }

    private func removeRecommendationCandidate(userId: Int) {
        for railIndex in peopleRecommendationRails.indices {
            peopleRecommendationRails[railIndex].items.removeAll(where: { $0.user.id == userId })
        }
    }

    private func handleFollowStateStoreUpdate(_ followingUserIds: Set<Int>) {
        let newlyFollowed = followingUserIds.subtracting(lastObservedFollowingUserIds)
        let noLongerFollowed = lastObservedFollowingUserIds.subtracting(followingUserIds)
        lastObservedFollowingUserIds = followingUserIds

        if !newlyFollowed.isEmpty {
            connectedRecommendationUserIds.formUnion(newlyFollowed)
        }
        if !noLongerFollowed.isEmpty {
            connectedRecommendationUserIds.subtract(noLongerFollowed)
        }
    }

    private func syncKnownFollowingRecommendationCandidates() {
        let recommendationUserIds = Set(
            peopleRecommendationRails
                .flatMap { $0.items }
                .map { $0.user.id }
        )
        let knownFollowingUserIds = recommendationUserIds.intersection(followStateStore.followingUserIds)
        if !knownFollowingUserIds.isEmpty {
            connectedRecommendationUserIds.formUnion(knownFollowingUserIds)
        }
    }
}
