import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedTrendingIndex = 0
    @Published var trendingPosts: [TrendingPost] = []
    @Published var loops: [LoopCategory] = []
    @Published var professions: [CommunitySearchResult] = []
    @Published var professionsError: String?

    private let communityService: CommunityServiceProtocol
    private let feedService: FeedServiceProtocol

    init(
        communityService: CommunityServiceProtocol = CommunityService(),
        feedService: FeedServiceProtocol = FeedService()
    ) {
        self.communityService = communityService
        self.feedService = feedService
        loadStaticContent()
        Task {
            await loadProfessions()
        }
        Task {
            await loadTrendingPosts()
        }
    }

    private func loadStaticContent() {
        loops = MockSearchContent.loopCategories
        professions = MockSearchContent.professions
    }

    func loadProfessions() async {
        do {
            let items = try await communityService.fetchTopProfessionCommunities(limit: 12)
            professions = items
            professionsError = nil
        } catch {
            professionsError = error.localizedDescription
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
}
