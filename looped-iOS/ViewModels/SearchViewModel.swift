import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedTrendingIndex = 0
    @Published var trendingPosts: [TrendingPost] = []
    @Published var loops: [Loop] = []
    @Published var groups: [SearchGroup] = []

    init() {
        loadMockData()
    }

    private func loadMockData() {
        // Mock trending posts data
        trendingPosts = [
            TrendingPost(
                id: UUID(),
                imageName: "trending1",
                title: "Remote work productivity tips that actually work",
                subtitle: "Trending in Business"
            ),
            TrendingPost(
                id: UUID(),
                imageName: "trending2",
                title: "Latest iOS development best practices",
                subtitle: "Trending in Tech"
            ),
            TrendingPost(
                id: UUID(),
                imageName: "trending3",
                title: "Design system updates and new components",
                subtitle: "Trending in Design"
            )
        ]

        // Mock loops data
        loops = [
            Loop(
                id: UUID(),
                title: "Engineering",
                description: "Tech discussions and career development",
                memberCount: 1250
            ),
            Loop(
                id: UUID(),
                title: "Design",
                description: "UX/UI inspiration and feedback",
                memberCount: 890
            ),
            Loop(
                id: UUID(),
                title: "Marketing",
                description: "Growth strategies and campaigns",
                memberCount: 640
            ),
            Loop(
                id: UUID(),
                title: "Sales",
                description: "Deal strategies and customer insights",
                memberCount: 520
            )
        ]

        // Mock groups data
        groups = [
            SearchGroup(id: UUID(), title: "Tech", iconName: "laptopcomputer", memberCount: 2500),
            SearchGroup(id: UUID(), title: "Design", iconName: "paintbrush", memberCount: 1800),
            SearchGroup(id: UUID(), title: "Business", iconName: "briefcase", memberCount: 3200),
            SearchGroup(id: UUID(), title: "Finance", iconName: "chart.line.uptrend.xyaxis", memberCount: 1400),
            SearchGroup(id: UUID(), title: "Sales", iconName: "phone", memberCount: 980),
            SearchGroup(id: UUID(), title: "HR", iconName: "person.3", memberCount: 750),
            SearchGroup(id: UUID(), title: "Legal", iconName: "scale.3d", memberCount: 420),
            SearchGroup(id: UUID(), title: "Operations", iconName: "gear", memberCount: 1100),
            SearchGroup(id: UUID(), title: "Product", iconName: "cube.box", memberCount: 890),
            SearchGroup(id: UUID(), title: "Support", iconName: "headphones", memberCount: 340),
            SearchGroup(id: UUID(), title: "Security", iconName: "shield", memberCount: 280),
            SearchGroup(id: UUID(), title: "Analytics", iconName: "chart.bar", memberCount: 450)
        ]
    }
}

// MARK: - Data Models
struct TrendingPost: Identifiable {
    let id: UUID
    let imageName: String
    let title: String
    let subtitle: String
}

struct Loop: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let memberCount: Int
}

struct SearchGroup: Identifiable {
    let id: UUID
    let title: String
    let iconName: String
    let memberCount: Int
}