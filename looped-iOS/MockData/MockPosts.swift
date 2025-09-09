import Foundation

struct MockPosts {
    
    // MARK: - Sample Posts for Feed
    static let feedPosts: [Post] = [
        // Figma example post
        Post(
            id: UUID(),
            content: "Excited to share my latest project, a redesign of our user onboarding flow. Focused on simplicity and clarity, resulting in a 20% increase in user retention. Check it out and let me know your thoughts! #uxdesign #productdesign",
            authorId: MockUsers.colleagues[0].id, // Sarah Chen
            authorDisplayName: "Sarah Chen",
            company: "Looped",
            isAnonymous: false,
            reactionCount: 188,
            userReaction: .like,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ),
        Post(
            id: UUID(),
            content: "Just shipped a major feature! 🚀 The new search functionality is lightning fast. Shoutout to the entire engineering team for the late nights debugging.",
            authorId: MockUsers.colleagues[0].id, // Sarah
            authorDisplayName: MockUsers.colleagues[0].displayName,
            company: "Anthropic",
            isAnonymous: false,
            reactionCount: 12,
            userReaction: .like,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        ),
        
        Post(
            id: UUID(),
            content: "Anyone else feel like our office coffee machine is plotting against us? Third time this week it's been 'out of order' right when I need my afternoon caffeine fix ☕️😤",
            authorId: MockUsers.colleagues[1].id, // Mike
            authorDisplayName: MockUsers.colleagues[1].displayName,
            company: "Anthropic",
            isAnonymous: false,
            reactionCount: 23,
            userReaction: .laugh,
            createdAt: Calendar.current.date(byAdding: .hour, value: -4, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .hour, value: -4, to: Date())!
        ),
        
        Post(
            id: UUID(),
            content: "Hot take: our current sprint planning process is broken. We consistently overcommit and then stress about hitting deadlines. Maybe it's time to try something different?",
            authorId: MockUsers.colleagues[5].id, // Anonymous user
            authorDisplayName: nil,
            company: "Anthropic",
            isAnonymous: true,
            reactionCount: 8,
            userReaction: nil,
            createdAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!
        ),
        
        Post(
            id: UUID(),
            content: "Celebrating our Q3 numbers! 📈 Revenue is up 34% from last quarter. Couldn't have done it without this amazing team. Pizza party in the break room at 3pm!",
            authorId: MockUsers.colleagues[2].id, // Alex
            authorDisplayName: MockUsers.colleagues[2].displayName,
            company: "Anthropic",
            isAnonymous: false,
            reactionCount: 31,
            userReaction: .love,
            createdAt: Calendar.current.date(byAdding: .hour, value: -8, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .hour, value: -8, to: Date())!
        ),
        
        Post(
            id: UUID(),
            content: "New design system is looking 🔥🔥🔥 Can't wait for everyone to see what we've been cooking up. The color palette alone is going to make our product stand out.",
            authorId: MockUsers.colleagues[1].id, // Mike (design)
            authorDisplayName: MockUsers.colleagues[1].displayName,
            company: "Anthropic",
            isAnonymous: false,
            reactionCount: 17,
            userReaction: .wow,
            createdAt: Calendar.current.date(byAdding: .hour, value: -12, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .hour, value: -12, to: Date())!
        ),
        
        Post(
            id: UUID(),
            content: "Does anyone know why the parking garage elevator has been making that weird grinding noise? It's been going on for weeks and honestly it's starting to sound like a horror movie soundtrack 😱",
            authorId: MockUsers.colleagues[3].id, // Jenny
            authorDisplayName: MockUsers.colleagues[3].displayName,
            company: "Anthropic",
            isAnonymous: false,
            reactionCount: 5,
            userReaction: nil,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ),
        
        Post(
            id: UUID(),
            content: "Unpopular opinion: I actually like our new open office layout. Yes, it can get noisy, but the collaboration and spontaneous conversations are worth it. Maybe we just need better noise-canceling headphones?",
            authorId: MockUsers.colleagues[5].id, // Anonymous
            authorDisplayName: nil,
            company: "Anthropic",
            isAnonymous: true,
            reactionCount: 14,
            userReaction: .angry,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ),
        
        Post(
            id: UUID(),
            content: "Server migration completed successfully! 🎉 Zero downtime and everything is running 40% faster now. Thanks to the DevOps team for making this seamless.",
            authorId: MockUsers.colleagues[4].id, // David (ops)
            authorDisplayName: MockUsers.colleagues[4].displayName,
            company: "Anthropic",
            isAnonymous: false,
            reactionCount: 28,
            userReaction: .like,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        ),
        
        Post(
            id: UUID(),
            content: "Quick reminder: All-hands meeting tomorrow at 2pm in the main conference room. We'll be discussing the new product roadmap and Q4 goals. Pizza will be provided 🍕",
            authorId: MockUsers.colleagues[2].id, // Alex (PM)
            authorDisplayName: MockUsers.colleagues[2].displayName,
            company: "Anthropic",
            isAnonymous: false,
            reactionCount: 9,
            userReaction: nil,
            createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        ),
        
        Post(
            id: UUID(),
            content: "Is it just me or has the office been really cold lately? I'm wearing a sweater in September. Can someone check the thermostat? My fingers are too cold to type properly 🥶",
            authorId: MockUsers.colleagues[5].id, // Anonymous
            authorDisplayName: nil,
            company: "Anthropic",
            isAnonymous: true,
            reactionCount: 19,
            userReaction: .sad,
            createdAt: Calendar.current.date(byAdding: .day, value: -4, to: Date())!,
            updatedAt: Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        )
    ]
    
    // MARK: - Helper Functions
    static func getRecentPosts() -> [Post] {
        return feedPosts.sorted { $0.createdAt > $1.createdAt }
    }
    
    static func getPopularPosts() -> [Post] {
        return feedPosts.sorted { $0.reactionCount > $1.reactionCount }
    }
    
    static func getAnonymousPosts() -> [Post] {
        return feedPosts.filter { $0.isAnonymous }
    }
    
    static func getPostsByUser(_ userId: UUID) -> [Post] {
        return feedPosts.filter { $0.authorId == userId }
    }
    
    static func addReaction(to postId: UUID, reaction: ReactionType) -> Post? {
        // In real app, this would be handled by backend
        // For mock data, we can simulate the reaction
        guard let postIndex = feedPosts.firstIndex(where: { $0.id == postId }) else { return nil }
        let updatedPost = feedPosts[postIndex]
        
        // Simple mock logic: toggle reaction
        if updatedPost.userReaction == reaction {
            // Remove reaction
            return Post(
                id: updatedPost.id,
                content: updatedPost.content,
                authorId: updatedPost.authorId,
                authorDisplayName: updatedPost.authorDisplayName,
                company: updatedPost.company,
                isAnonymous: updatedPost.isAnonymous,
                reactionCount: max(0, updatedPost.reactionCount - 1),
                userReaction: nil,
                createdAt: updatedPost.createdAt,
                updatedAt: Date()
            )
        } else {
            // Add reaction
            return Post(
                id: updatedPost.id,
                content: updatedPost.content,
                authorId: updatedPost.authorId,
                authorDisplayName: updatedPost.authorDisplayName,
                company: updatedPost.company,
                isAnonymous: updatedPost.isAnonymous,
                reactionCount: updatedPost.reactionCount + 1,
                userReaction: reaction,
                createdAt: updatedPost.createdAt,
                updatedAt: Date()
            )
        }
    }
    
    // MARK: - Create New Post (for testing create functionality)
    static func createPost(content: String, isAnonymous: Bool = false) -> Post {
        return Post(
            id: UUID(),
            content: content,
            authorId: MockUsers.currentUser.id,
            authorDisplayName: isAnonymous ? nil : MockUsers.currentUser.displayName,
            company: MockUsers.currentUser.company,
            isAnonymous: isAnonymous,
            reactionCount: 0,
            userReaction: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
