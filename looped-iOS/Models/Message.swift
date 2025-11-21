import Foundation

struct Message: Codable, Identifiable {
    let id: UUID
    let backendId: Int
    let content: String
    let senderId: UUID
    let senderDisplayName: String?
    let receiverId: UUID?
    let conversationBackendId: Int?
    let channelBackendId: Int?
    let messageType: MessageType
    let isRead: Bool
    let attachments: [MediaAttachment]?
    let createdAt: Date
}

enum MessageType: String, Codable {
    case direct = "direct"
    case channel = "channel"
}

struct Channel: Codable, Identifiable {
    let id: UUID
    let backendId: Int
    let name: String
    let company: String
    let memberCount: Int
    let isPublic: Bool
    let createdAt: Date
}

struct ConversationPage {
    let conversations: [Conversation]
    let nextCursor: String?
}

struct ChannelPage {
    let channels: [Channel]
    let nextCursor: String?
}

struct MessagePage {
    let messages: [Message]
    let nextCursor: String?
}
