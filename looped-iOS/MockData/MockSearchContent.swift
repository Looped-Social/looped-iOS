import Foundation

struct MockSearchContent {
    static let trendingPosts: [TrendingPost] = [
        TrendingPost(
            id: 1,
            imageURL: "trending1",
            title: "Remote work productivity tips that actually work",
            subtitle: "Trending in Business"
        ),
        TrendingPost(
            id: 2,
            imageURL: "trending2",
            title: "Latest iOS development best practices",
            subtitle: "Trending in Tech"
        ),
        TrendingPost(
            id: 3,
            imageURL: "trending3",
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

    static let fields: [CommunitySearchResult] = [
        CommunitySearchResult(id: 1, name: "Design", description: "UX, UI, and product design", kind: .specialization, specializationType: .field, memberCount: 1800),
        CommunitySearchResult(id: 2, name: "Engineering", description: "Build, ship, and debug", kind: .specialization, specializationType: .field, memberCount: 2500),
        CommunitySearchResult(id: 3, name: "Marketing", description: "Growth and campaigns", kind: .specialization, specializationType: .field, memberCount: 1200),
        CommunitySearchResult(id: 4, name: "Sales", description: "Pipeline and playbooks", kind: .specialization, specializationType: .field, memberCount: 980),
        CommunitySearchResult(id: 5, name: "HR", description: "People and culture", kind: .specialization, specializationType: .field, memberCount: 760),
        CommunitySearchResult(id: 6, name: "Finance", description: "Planning and strategy", kind: .specialization, specializationType: .field, memberCount: 860),
        CommunitySearchResult(id: 7, name: "Legal", description: "Policy and compliance", kind: .specialization, specializationType: .field, memberCount: 420),
        CommunitySearchResult(id: 8, name: "Operations", description: "Execution and ops", kind: .specialization, specializationType: .field, memberCount: 640)
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

    static let communities: [SearchResultLoop] = [
        SearchResultLoop(backendId: 1, name: "Finance", description: "Markets, comp, and insights", memberCount: 1200),
        SearchResultLoop(backendId: 2, name: "New Hires", description: "Onboarding tips and questions", memberCount: 640),
        SearchResultLoop(backendId: 3, name: "Engineering", description: "Build, ship, and debug", memberCount: 980),
        SearchResultLoop(backendId: 4, name: "Product", description: "Roadmaps and strategy", memberCount: 540),
        SearchResultLoop(backendId: 5, name: "Design", description: "UX feedback and inspiration", memberCount: 430),
        SearchResultLoop(backendId: 6, name: "Company Culture", description: "Events and happenings", memberCount: 760),
        SearchResultLoop(backendId: 7, name: "Benefits & HR", description: "Policies and resources", memberCount: 390),
        SearchResultLoop(backendId: 8, name: "Sales", description: "Pipeline and playbooks", memberCount: 420)
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
