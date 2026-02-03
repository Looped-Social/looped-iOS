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
    @Published var isLoadingMoreMajors = false
    @Published var isLoadingMoreFields = false
    @Published var specializationsError: String?

    private let communityService: CommunityServiceProtocol
    private let feedService: FeedServiceProtocol
    private let discoveryService: DiscoveryServiceProtocol
    private var majorsNextCursor: String?
    private var fieldsNextCursor: String?
    private let initialSpecializationsLimit = 24
    private let loadMoreSpecializationsLimit = 40

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
            appendUnique(items: page.items, to: &majors)
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
            appendUnique(items: page.items, to: &fields)
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
            trendingPosts = try await feedService.fetchTrendingPosts(limit: 3, communityId: nil)
            selectedTrendingIndex = 0
        } catch {
            trendingPosts = []
        }
    }

    func loadRecommendedCommunities() async {
        do {
            recommendedCommunities = try await communityService.fetchRecommendedCommunities(kind: nil, limit: 8)
        } catch {
            recommendedCommunities = []
        }
    }
}
