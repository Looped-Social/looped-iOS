import Foundation

struct MockUsers {
    
    // MARK: - Current User (Simulated Logged In User)
    static let currentUser = User(
        id: MockConfig.currentUserId,
        username: "you",
        displayName: "Your Name",
        handle: "yourhandle",
        company: "Anthropic",
        bio: "Building the future of AI",
        profileImageURL: "https://via.placeholder.com/100",
        isVerified: true,
        isAnonymous: false,
        createdAt: Calendar.current.date(byAdding: .month, value: -3, to: Date())!,
        updatedAt: Date()
    )
    
    // MARK: - Company Colleagues
    static let colleagues: [User] = [
        User(
            id: UUID(uuidString: "223e4567-e89b-12d3-a456-426614174001")!,
            username: "sarah_dev",
            displayName: "Sarah Chen",
            handle: "sarah.dev",
            company: "Anthropic",
            bio: "Software engineer passionate about ML",
            profileImageURL: "https://via.placeholder.com/100",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
            updatedAt: Date()
        ),

        User(
            id: UUID(uuidString: "323e4567-e89b-12d3-a456-426614174002")!,
            username: "mike_design",
            displayName: "Mike Rodriguez",
            handle: "mike.design",
            company: "Anthropic",
            bio: "UI/UX designer creating delightful experiences",
            profileImageURL: "https://via.placeholder.com/100",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -1, to: Date())!,
            updatedAt: Date()
        ),

        User(
            id: UUID(uuidString: "423e4567-e89b-12d3-a456-426614174003")!,
            username: "alex_pm",
            displayName: "Alex Kim",
            handle: "alex.pm",
            company: "Anthropic",
            bio: "Product manager | Coffee enthusiast",
            profileImageURL: "https://via.placeholder.com/100",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .weekOfYear, value: -3, to: Date())!,
            updatedAt: Date()
        ),

        User(
            id: UUID(uuidString: "523e4567-e89b-12d3-a456-426614174004")!,
            username: "jenny_marketing",
            displayName: "Jennifer Liu",
            handle: "jenny.marketing",
            company: "Anthropic",
            bio: "Marketing lead spreading the AI word",
            profileImageURL: "https://via.placeholder.com/100",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!,
            updatedAt: Date()
        ),

        User(
            id: UUID(uuidString: "623e4567-e89b-12d3-a456-426614174005")!,
            username: "david_ops",
            displayName: "David Park",
            handle: "david.ops",
            company: "Anthropic",
            bio: "DevOps engineer keeping things running",
            profileImageURL: "https://via.placeholder.com/100",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            updatedAt: Date()
        ),

        // Anonymous user example
        User(
            id: UUID(uuidString: "723e4567-e89b-12d3-a456-426614174006")!,
            username: "anon_user_1",
            displayName: nil,
            handle: "anonymous",
            company: "Anthropic",
            bio: nil,
            profileImageURL: nil,
            isVerified: true,
            isAnonymous: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            updatedAt: Date()
        )
    ]
    
    // MARK: - All Users (Current + Colleagues)
    static let allUsers: [User] = [currentUser] + colleagues
    
    // MARK: - Helper Functions
    static func getUserById(_ id: UUID) -> User? {
        return allUsers.first { $0.id == id }
    }
    
    static func getRandomColleague() -> User {
        return colleagues.randomElement()!
    }
    
    static func getAnonymousUsers() -> [User] {
        return allUsers.filter { $0.isAnonymous }
    }
    
    static func getVerifiedUsers() -> [User] {
        return allUsers.filter { $0.isVerified }
    }
}