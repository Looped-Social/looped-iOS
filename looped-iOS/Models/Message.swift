import Foundation

struct Message: Codable, Identifiable {
    let id: UUID
    let content: String
    let senderId: UUID
    let senderDisplayName: String?
    let receiverId: UUID?
    let channelId: UUID?
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
    let name: String
    let company: String
    let memberCount: Int
    let isPublic: Bool
    let createdAt: Date
}