import Foundation

struct MockConversations {

    // MARK: - Additional Users for Conversations
    static let conversationUsers: [User] = [
        User(
            id: UUID(uuidString: "801e4567-e89b-12d3-a456-426614174001")!,
            username: "sujeet",
            displayName: "Sujeet",
            company: "Anthropic",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
            updatedAt: Date()
        ),

        User(
            id: UUID(uuidString: "801e4567-e89b-12d3-a456-426614174002")!,
            username: "shivam",
            displayName: "Shivam",
            company: "Anthropic",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
            updatedAt: Date()
        ),

        User(
            id: UUID(uuidString: "801e4567-e89b-12d3-a456-426614174003")!,
            username: "anuj",
            displayName: "Anuj",
            company: "Anthropic",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
            updatedAt: Date()
        ),

        User(
            id: UUID(uuidString: "801e4567-e89b-12d3-a456-426614174004")!,
            username: "gurmeet",
            displayName: "Gurmeet",
            company: "Anthropic",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
            updatedAt: Date()
        ),

        User(
            id: UUID(uuidString: "801e4567-e89b-12d3-a456-426614174005")!,
            username: "jitendra",
            displayName: "Jitendra",
            company: "Anthropic",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
            updatedAt: Date()
        ),

        User(
            id: UUID(uuidString: "801e4567-e89b-12d3-a456-426614174006")!,
            username: "abhishek",
            displayName: "Abhishek",
            company: "Anthropic",
            isVerified: true,
            isAnonymous: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date())!,
            updatedAt: Date()
        )
    ]

    // MARK: - Mock Conversations (matching the design exactly)
    static let conversations: [Conversation] = [
        // Intro Interns - Group Chat
        Conversation(
            userId: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!, // Special UUID for group
            userName: "Intro Interns",
            userProfileImageUrl: nil, // No profile image for groups
            lastMessage: "Fr, hungry as fck",
            lastMessageTimestamp: Calendar.current.date(byAdding: .minute, value: -5, to: Date())!,
            unreadCount: 2,
            hasSpecialStatus: false,
            isOnline: false
        ),
        // Sujeet - "Happy Journey Bro" (20/3/22)
        Conversation(
            userId: conversationUsers[0].id,
            userName: "Sujeet",
            userProfileImageUrl: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Happy Journey Bro",
            lastMessageTimestamp: Calendar.current.date(from: DateComponents(year: 2022, month: 3, day: 20, hour: 10, minute: 30))!,
            unreadCount: 0
        ),

        // Sujeet - "Happy Journey Bro" (20/3/22) - duplicate for design accuracy
        Conversation(
            userId: conversationUsers[0].id,
            userName: "Sujeet",
            userProfileImageUrl: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Happy Journey Bro",
            lastMessageTimestamp: Calendar.current.date(from: DateComponents(year: 2022, month: 3, day: 20, hour: 9, minute: 15))!,
            unreadCount: 0
        ),

        // Shivam - "Good Evening Bhai" (6:37) with unread count
        Conversation(
            userId: conversationUsers[1].id,
            userName: "Shivam",
            userProfileImageUrl: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Good Evening Bhai",
            lastMessageTimestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!,
            unreadCount: 1
        ),

        // Anuj - "Well Done" (4:46)
        Conversation(
            userId: conversationUsers[2].id,
            userName: "Anuj",
            userProfileImageUrl: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Well Done",
            lastMessageTimestamp: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!,
            unreadCount: 0
        ),

        // Gurmeet - "Have a Great Day" (9:41) with special status
        Conversation(
            userId: conversationUsers[3].id,
            userName: "Gurmeet",
            userProfileImageUrl: "https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Have a Great Day",
            lastMessageTimestamp: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!,
            unreadCount: 0,
            hasSpecialStatus: true
        ),

        // Jitendra - "Send Successfully" (7:51)
        Conversation(
            userId: conversationUsers[4].id,
            userName: "Jitendra",
            userProfileImageUrl: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Send Successfully",
            lastMessageTimestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!,
            unreadCount: 0
        ),

        // Abhishek - "Kb Ayega Jsr" (21/3/22)
        Conversation(
            userId: conversationUsers[5].id,
            userName: "Abhishek",
            userProfileImageUrl: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Kb Ayega Jsr",
            lastMessageTimestamp: Calendar.current.date(from: DateComponents(year: 2022, month: 3, day: 21, hour: 14, minute: 20))!,
            unreadCount: 0
        ),

        // Sujeet - "Happy Journey Bro" (20/3/22) - another duplicate
        Conversation(
            userId: conversationUsers[0].id,
            userName: "Sujeet",
            userProfileImageUrl: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Happy Journey Bro",
            lastMessageTimestamp: Calendar.current.date(from: DateComponents(year: 2022, month: 3, day: 20, hour: 16, minute: 45))!,
            unreadCount: 0
        ),

        // Abhishek - "Kb Ayega Jsr" (21/3/...) - cut off timestamp
        Conversation(
            userId: conversationUsers[5].id,
            userName: "Abhishek",
            userProfileImageUrl: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Kb Ayega Jsr",
            lastMessageTimestamp: Calendar.current.date(from: DateComponents(year: 2022, month: 3, day: 21, hour: 11, minute: 10))!,
            unreadCount: 0
        )
    ]

    // MARK: - Helper Functions
    static func getConversationById(_ id: UUID) -> Conversation? {
        return conversations.first { $0.id == id }
    }

    static func getConversationsForUser(_ userId: UUID) -> [Conversation] {
        return conversations.filter { $0.userId == userId }
    }

    static func getUnreadConversations() -> [Conversation] {
        return conversations.filter { $0.hasUnreadMessages }
    }

    static func getTotalUnreadCount() -> Int {
        return conversations.reduce(0) { $0 + $1.unreadCount }
    }

    static func isGroupConversation(_ conversation: Conversation) -> Bool {
        return conversation.userId.uuidString.uppercased() == "12345678-1234-1234-1234-123456789ABC"
    }

    static func getChannelForGroupConversation(_ conversation: Conversation) -> Channel? {
        guard isGroupConversation(conversation) else { return nil }

        // Return a mock channel for the group conversation
        return Channel(
            id: conversation.userId,
            name: conversation.userName,
            company: "Anthropic",
            memberCount: 5,
            isPublic: true,
            createdAt: Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        )
    }
}