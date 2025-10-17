import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedTrendingIndex = 0
    @Published var trendingPosts: [TrendingPost] = []
    @Published var loops: [LoopCategory] = []
    @Published var groups: [SearchGroup] = []

    init() {
        loadMockData()
    }

    private func loadMockData() {
        trendingPosts = MockSearchContent.trendingPosts
        loops = MockSearchContent.loopCategories
        groups = MockSearchContent.groups
    }
}
