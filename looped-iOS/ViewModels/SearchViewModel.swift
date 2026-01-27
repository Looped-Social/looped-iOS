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
    @Published var specializationsError: String?

    private let communityService: CommunityServiceProtocol
    private let feedService: FeedServiceProtocol
    private let discoveryService: DiscoveryServiceProtocol

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
        do {
            let results = try await discoveryService.fetchRecommendedSpecializations(limit: 12)
            majors = results.majors
            fields = results.fields
            specializationsError = nil
        } catch {
            majors = []
            fields = []
            specializationsError = error.localizedDescription
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
