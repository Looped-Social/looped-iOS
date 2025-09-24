import Foundation

struct MockUserProfiles {

    // MARK: - Sample User Profiles
    static let profiles: [UserProfile] = [
        // Sarah Chen - from Figma design
        UserProfile(
            id: MockUsers.colleagues[0].id,
            username: "sarah_dev",
            displayName: "Sarah Chen",
            handle: "sarah58",
            company: "Looped",
            jobTitle: "Product Designer",
            bio: "Hello, i am Billy Bob. Always looking for new connections. Feel free to reach out!",
            profileImageURL: "https://via.placeholder.com/80",
            isVerified: true,
            isAnonymous: false,
            yearsInLoop: 2,
            followingCount: 100,
            followersCount: 123,
            postsCount: 42,
            commentsCount: 128,
            isCurrentUser: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -24, to: Date())!,
            updatedAt: Date()
        ),

        // Mike Rodriguez
        UserProfile(
            id: MockUsers.colleagues[1].id,
            username: "mike_design",
            displayName: "Mike Rodriguez",
            handle: "mike_design",
            company: "Looped",
            jobTitle: "Senior UX Designer",
            bio: "Design thinking enthusiast. Always looking for ways to improve user experience through thoughtful design.",
            profileImageURL: "https://via.placeholder.com/80",
            isVerified: true,
            isAnonymous: false,
            yearsInLoop: 1,
            followingCount: 89,
            followersCount: 156,
            postsCount: 28,
            commentsCount: 94,
            isCurrentUser: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -12, to: Date())!,
            updatedAt: Date()
        ),

        // Alex Kim
        UserProfile(
            id: MockUsers.colleagues[2].id,
            username: "alex_pm",
            displayName: "Alex Kim",
            handle: "alex_pm",
            company: "Looped",
            jobTitle: "Product Manager",
            bio: "Building products that matter. Coffee lover ☕️ and weekend hiker 🥾. Let's ship something amazing together!",
            profileImageURL: "https://via.placeholder.com/80",
            isVerified: true,
            isAnonymous: false,
            yearsInLoop: 3,
            followingCount: 145,
            followersCount: 203,
            postsCount: 67,
            commentsCount: 189,
            isCurrentUser: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -36, to: Date())!,
            updatedAt: Date()
        ),

        // Jennifer Liu
        UserProfile(
            id: MockUsers.colleagues[3].id,
            username: "jenny_marketing",
            displayName: "Jennifer Liu",
            handle: "jenny_marketing",
            company: "Looped",
            jobTitle: "Marketing Manager",
            bio: "Growth hacker by day, foodie by night 🍜. Always experimenting with new campaigns and strategies.",
            profileImageURL: "https://via.placeholder.com/80",
            isVerified: true,
            isAnonymous: false,
            yearsInLoop: 2,
            followingCount: 167,
            followersCount: 234,
            postsCount: 89,
            commentsCount: 245,
            isCurrentUser: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -24, to: Date())!,
            updatedAt: Date()
        ),

        // David Park
        UserProfile(
            id: MockUsers.colleagues[4].id,
            username: "david_ops",
            displayName: "David Park",
            handle: "david_ops",
            company: "Looped",
            jobTitle: "DevOps Engineer",
            bio: "Infrastructure wizard 🧙‍♂️. Making sure everything runs smoothly so you don't have to worry about it.",
            profileImageURL: "https://via.placeholder.com/80",
            isVerified: true,
            isAnonymous: false,
            yearsInLoop: 1,
            followingCount: 78,
            followersCount: 145,
            postsCount: 23,
            commentsCount: 67,
            isCurrentUser: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -12, to: Date())!,
            updatedAt: Date()
        ),

        // Current User
        UserProfile(
            id: MockUsers.currentUser.id,
            username: "you",
            displayName: "Billy Bob",
            handle: "billy.bob24",
            company: "Google",
            jobTitle: "Software Engineer",
            bio: "Hello, i am Billy Bob. Always looking for new connections. Feel free to reach out!",
            profileImageURL: "https://via.placeholder.com/80",
            isVerified: true,
            isAnonymous: false,
            yearsInLoop: 2,
            followingCount: 100,
            followersCount: 123,
            postsCount: 34,
            commentsCount: 156,
            isCurrentUser: true,
            createdAt: Calendar.current.date(byAdding: .month, value: -24, to: Date())!,
            updatedAt: Date()
        )
    ]

    // MARK: - Helper Functions
    static func getUserProfile(byId id: UUID) -> UserProfile? {
        return profiles.first { $0.id == id }
    }

    static func getUserProfile(byUsername username: String) -> UserProfile? {
        return profiles.first { $0.username == username }
    }

    static func getUserProfile(byHandle handle: String) -> UserProfile? {
        return profiles.first { $0.handle == handle }
    }

    static func getCurrentUserProfile() -> UserProfile? {
        return profiles.first { $0.isCurrentUser }
    }

    static func getRandomUserProfile() -> UserProfile {
        return profiles.filter { !$0.isCurrentUser }.randomElement()!
    }

    static func searchUserProfiles(query: String) -> [UserProfile] {
        let lowercaseQuery = query.lowercased()
        return profiles.filter { profile in
            profile.displayName?.lowercased().contains(lowercaseQuery) == true ||
            profile.username.lowercased().contains(lowercaseQuery) ||
            profile.handle.lowercased().contains(lowercaseQuery) ||
            profile.jobTitle.lowercased().contains(lowercaseQuery)
        }
    }
}