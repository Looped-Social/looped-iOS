import Foundation

struct MockSearchContent {
    static let trendingPosts: [TrendingPost] = [
        TrendingPost(
            imageName: "trending1",
            title: "Remote work productivity tips that actually work",
            subtitle: "Trending in Business"
        ),
        TrendingPost(
            imageName: "trending2",
            title: "Latest iOS development best practices",
            subtitle: "Trending in Tech"
        ),
        TrendingPost(
            imageName: "trending3",
            title: "Design system updates and new components",
            subtitle: "Trending in Design"
        )
    ]

    static let loopCategories: [LoopCategory] = [
        LoopCategory(
            title: "Engineering",
            description: "Tech discussions and career development",
            memberCount: 1250
        ),
        LoopCategory(
            title: "Design",
            description: "UX/UI inspiration and feedback",
            memberCount: 890
        ),
        LoopCategory(
            title: "Marketing",
            description: "Growth strategies and campaigns",
            memberCount: 640
        ),
        LoopCategory(
            title: "Sales",
            description: "Deal strategies and customer insights",
            memberCount: 520
        )
    ]

    static let groups: [SearchGroup] = [
        SearchGroup(title: "Tech", iconName: "laptopcomputer", memberCount: 2500),
        SearchGroup(title: "Design", iconName: "paintbrush", memberCount: 1800),
        SearchGroup(title: "Business", iconName: "briefcase", memberCount: 3200),
        SearchGroup(title: "Finance", iconName: "chart.line.uptrend.xyaxis", memberCount: 1400),
        SearchGroup(title: "Sales", iconName: "phone", memberCount: 980),
        SearchGroup(title: "HR", iconName: "person.3", memberCount: 750),
        SearchGroup(title: "Legal", iconName: "scale.3d", memberCount: 420),
        SearchGroup(title: "Operations", iconName: "gear", memberCount: 1100),
        SearchGroup(title: "Product", iconName: "cube.box", memberCount: 890),
        SearchGroup(title: "Support", iconName: "headphones", memberCount: 340),
        SearchGroup(title: "Security", iconName: "shield", memberCount: 280),
        SearchGroup(title: "Analytics", iconName: "chart.bar", memberCount: 450)
    ]

    static let defaultRecentSearches: [String] = [
        "elevator broken",
        "Lunch Break Shortened",
        "#interns"
    ]

    static let popularHashtags: [String] = [
        "#interns", "#lunch", "#elevator", "#remote", "#office", "#meeting",
        "#project", "#deadline", "#coffee", "#team", "#collaboration", "#innovation"
    ]

    static var filterOptions: [SearchFilterOption] {
        [
            SearchFilterOption(title: "All Loops", apiKey: "all"),
            SearchFilterOption(title: companyFilterTitle, apiKey: "company"),
            SearchFilterOption(title: "Finance", apiKey: "finance"),
            SearchFilterOption(title: "Investment", apiKey: "investment")
        ]
    }

    static var companyFilterTitle: String {
        MockUsers.currentUser.company
    }
}
