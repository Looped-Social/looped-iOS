import Foundation

struct MockMessages {
    
    // MARK: - Mock Channels
    static let channels: [Channel] = [
        Channel(
            id: UUID(uuidString: "111e4567-e89b-12d3-a456-426614174000")!,
            name: "🏢 general",
            company: "Anthropic",
            memberCount: 47,
            isPublic: true,
            createdAt: Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        ),
        
        Channel(
            id: UUID(uuidString: "222e4567-e89b-12d3-a456-426614174000")!,
            name: "💻 engineering",
            company: "Anthropic",
            memberCount: 23,
            isPublic: true,
            createdAt: Calendar.current.date(byAdding: .month, value: -5, to: Date())!
        ),
        
        Channel(
            id: UUID(uuidString: "333e4567-e89b-12d3-a456-426614174000")!,
            name: "🎨 design",
            company: "Anthropic",
            memberCount: 8,
            isPublic: true,
            createdAt: Calendar.current.date(byAdding: .month, value: -4, to: Date())!
        ),
        
        Channel(
            id: UUID(uuidString: "444e4567-e89b-12d3-a456-426614174000")!,
            name: "📈 marketing",
            company: "Anthropic",
            memberCount: 12,
            isPublic: true,
            createdAt: Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        ),
        
        Channel(
            id: UUID(uuidString: "555e4567-e89b-12d3-a456-426614174000")!,
            name: "🔒 leadership",
            company: "Anthropic",
            memberCount: 6,
            isPublic: false,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        ),
        
        Channel(
            id: UUID(uuidString: "666e4567-e89b-12d3-a456-426614174000")!,
            name: "🎮 random",
            company: "Anthropic",
            memberCount: 34,
            isPublic: true,
            createdAt: Calendar.current.date(byAdding: .weekOfYear, value: -8, to: Date())!
        )
    ]
    
    // MARK: - Messages for General Channel
    static let generalChannelMessages: [Message] = [
        Message(
            id: UUID(),
            content: "Good morning everyone! Hope you all have a productive day ahead 😊",
            senderId: MockUsers.colleagues[2].id, // Alex
            senderDisplayName: MockUsers.colleagues[2].displayName,
            receiverId: nil,
            channelId: channels[0].id, // general
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .minute, value: -15, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "Coffee machine is fixed! ☕️ Thanks to whoever reported it to facilities",
            senderId: MockUsers.colleagues[3].id, // Jenny
            senderDisplayName: MockUsers.colleagues[3].displayName,
            receiverId: nil,
            channelId: channels[0].id,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .minute, value: -12, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "🙌 Finally! I was about to bring my own espresso machine from home",
            senderId: MockUsers.colleagues[1].id, // Mike
            senderDisplayName: MockUsers.colleagues[1].displayName,
            receiverId: nil,
            channelId: channels[0].id,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .minute, value: -10, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "Quick reminder: parking lot will be resurfaced this weekend. Please move your cars by Friday evening.",
            senderId: MockUsers.colleagues[4].id, // David
            senderDisplayName: MockUsers.colleagues[4].displayName,
            receiverId: nil,
            channelId: channels[0].id,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .minute, value: -8, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "Does anyone have a phone charger I can borrow? Mine just died and I have calls all afternoon 😅",
            senderId: MockUsers.colleagues[0].id, // Sarah
            senderDisplayName: MockUsers.colleagues[0].displayName,
            receiverId: nil,
            channelId: channels[0].id,
            messageType: .channel,
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .minute, value: -3, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "I have an extra USB-C charger at my desk. Come by whenever!",
            senderId: MockUsers.currentUser.id,
            senderDisplayName: MockUsers.currentUser.displayName,
            receiverId: nil,
            channelId: channels[0].id,
            messageType: .channel,
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .minute, value: -1, to: Date())!
        )
    ]
    
    // MARK: - Messages for Engineering Channel
    static let engineeringChannelMessages: [Message] = [
        Message(
            id: UUID(),
            content: "Deploy went smooth this morning! All services are green ✅",
            senderId: MockUsers.colleagues[4].id, // David
            senderDisplayName: MockUsers.colleagues[4].displayName,
            receiverId: nil,
            channelId: channels[1].id, // engineering
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "Nice work on the optimization! Response times are down by 35%",
            senderId: MockUsers.colleagues[0].id, // Sarah
            senderDisplayName: MockUsers.colleagues[0].displayName,
            receiverId: nil,
            channelId: channels[1].id,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "Anyone else seeing weird behavior with the new caching layer? Getting some intermittent 500s",
            senderId: MockUsers.currentUser.id,
            senderDisplayName: MockUsers.currentUser.displayName,
            receiverId: nil,
            channelId: channels[1].id,
            messageType: .channel,
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "I'm not seeing any errors on my end. Can you share the error logs?",
            senderId: MockUsers.colleagues[4].id, // David
            senderDisplayName: MockUsers.colleagues[4].displayName,
            receiverId: nil,
            channelId: channels[1].id,
            messageType: .channel,
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .minute, value: -25, to: Date())!
        )
    ]
    
    // MARK: - Direct Messages
    static let directMessages: [Message] = [
        Message(
            id: UUID(),
            content: "Hey! Do you have a minute to review my PR? It's for the user authentication refactor",
            senderId: MockUsers.colleagues[0].id, // Sarah
            senderDisplayName: MockUsers.colleagues[0].displayName,
            receiverId: MockUsers.currentUser.id,
            channelId: nil,
            messageType: .direct,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "Sure! I'll take a look after lunch. Is it urgent?",
            senderId: MockUsers.currentUser.id,
            senderDisplayName: MockUsers.currentUser.displayName,
            receiverId: MockUsers.colleagues[0].id,
            channelId: nil,
            messageType: .direct,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        ),
        
        Message(
            id: UUID(),
            content: "Not super urgent, but would be great to get it in before the release on Friday. Thanks! 🙏",
            senderId: MockUsers.colleagues[0].id,
            senderDisplayName: MockUsers.colleagues[0].displayName,
            receiverId: MockUsers.currentUser.id,
            channelId: nil,
            messageType: .direct,
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .minute, value: -45, to: Date())!
        )
    ]
    
    // MARK: - Mock Group Chat Messages (Intro Interns)
    static let introInternsGroupMessages: [Message] = [
        Message(
            id: UUID(),
            content: "Wakey wakey",
            senderId: MockUsers.colleagues[0].id, // Sarah
            senderDisplayName: "Sarah",
            receiverId: nil,
            channelId: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!
        ),

        Message(
            id: UUID(),
            content: "Lets get this bread",
            senderId: MockUsers.colleagues[1].id, // Mike
            senderDisplayName: "Mike",
            receiverId: nil,
            channelId: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        ),

        Message(
            id: UUID(),
            content: "Bro shut up, its early",
            senderId: MockUsers.colleagues[2].id, // Alex
            senderDisplayName: "Alex",
            receiverId: nil,
            channelId: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        ),

        Message(
            id: UUID(),
            content: "It's morning in NY 😎",
            senderId: MockUsers.currentUser.id,
            senderDisplayName: MockUsers.currentUser.displayName,
            receiverId: nil,
            channelId: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .minute, value: -45, to: Date())!
        ),

        Message(
            id: UUID(),
            content: "I wonder how many bagels get bought evry morning",
            senderId: MockUsers.colleagues[3].id, // Jenny
            senderDisplayName: "Jenny",
            receiverId: nil,
            channelId: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!
        ),

        Message(
            id: UUID(),
            content: "I want a bagel",
            senderId: MockUsers.colleagues[4].id, // David
            senderDisplayName: "David",
            receiverId: nil,
            channelId: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            messageType: .channel,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .minute, value: -20, to: Date())!
        ),

        Message(
            id: UUID(),
            content: "Fr, hungry as fck",
            senderId: MockUsers.colleagues[0].id, // Sarah
            senderDisplayName: "Sarah",
            receiverId: nil,
            channelId: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            messageType: .channel,
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .minute, value: -5, to: Date())!
        )
    ]

    // MARK: - Helper Functions
    static func getMessagesForChannel(_ channelId: UUID) -> [Message] {
        switch channelId {
        case channels[0].id: // general
            return generalChannelMessages.sorted { $0.createdAt < $1.createdAt }
        case channels[1].id: // engineering
            return engineeringChannelMessages.sorted { $0.createdAt < $1.createdAt }
        case UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!: // Intro Interns group
            return introInternsGroupMessages.sorted { $0.createdAt < $1.createdAt }
        default:
            // For other channels, return some generic messages
            return [
                Message(
                    id: UUID(),
                    content: "This channel is pretty quiet... 🦗",
                    senderId: MockUsers.colleagues[1].id,
                    senderDisplayName: MockUsers.colleagues[1].displayName,
                    receiverId: nil,
                    channelId: channelId,
                    messageType: .channel,
                    isRead: true,
                    createdAt: Calendar.current.date(byAdding: .hour, value: -4, to: Date())!
                )
            ]
        }
    }
    
    static func getDirectMessages() -> [Message] {
        return directMessages.sorted { $0.createdAt < $1.createdAt }
    }
    
    static func getUnreadMessageCount() -> Int {
        let allMessages = generalChannelMessages + engineeringChannelMessages + directMessages
        return allMessages.filter { !$0.isRead }.count
    }
    
    static func sendMessage(content: String, to channelId: UUID) -> Message {
        return Message(
            id: UUID(),
            content: content,
            senderId: MockUsers.currentUser.id,
            senderDisplayName: MockUsers.currentUser.displayName,
            receiverId: nil,
            channelId: channelId,
            messageType: .channel,
            isRead: false,
            createdAt: Date()
        )
    }
    
    static func sendDirectMessage(content: String, to receiverId: UUID) -> Message {
        return Message(
            id: UUID(),
            content: content,
            senderId: MockUsers.currentUser.id,
            senderDisplayName: MockUsers.currentUser.displayName,
            receiverId: receiverId,
            channelId: nil,
            messageType: .direct,
            isRead: false,
            createdAt: Date()
        )
    }
}