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
    @Published var isLoadingSpecializations = false
    @Published var isLoadingMoreRecommendedCommunities = false
    @Published var isLoadingMoreMajors = false
    @Published var isLoadingMoreFields = false
    @Published var specializationsError: String?

    private let communityService: CommunityServiceProtocol
    private let feedService: FeedServiceProtocol
    private let discoveryService: DiscoveryServiceProtocol
    private var recommendedCommunitiesNextCursor: String?
    private var majorsNextCursor: String?
    private var fieldsNextCursor: String?
    private let initialSpecializationsLimit = 24
    private let loadMoreSpecializationsLimit = 40
    private let recommendedCommunitiesLimit = 8
    private let trendingPostsLimit = 20
    private var specializationIconsById: [Int: CommunityIcon] = [:]
    private var specializationIconsTask: Task<[Int: CommunityIcon], Never>?

    var majorsHasMorePages: Bool { majorsNextCursor?.isEmpty == false }
    var fieldsHasMorePages: Bool { fieldsNextCursor?.isEmpty == false }

    init(
        communityService: CommunityServiceProtocol = CommunityService(),
        feedService: FeedServiceProtocol = FeedService(),
        discoveryService: DiscoveryServiceProtocol = DiscoveryService()
    ) {
        self.communityService = communityService
        self.feedService = feedService
        self.discoveryService = discoveryService
        Task {
            await loadSpecializations()
        }
        Task {
            await loadRecommendedCommunities()
        }
        Task {
            await loadTrendingPosts()
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
}
