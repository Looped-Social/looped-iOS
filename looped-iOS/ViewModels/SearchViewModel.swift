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

    init(communityService: CommunityServiceProtocol = CommunityService()) {
        self.communityService = communityService
        loadMockData()
        Task {
            await loadProfessions()
        }
    }

    private func loadMockData() {
        trendingPosts = MockSearchContent.trendingPosts
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
}
