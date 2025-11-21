import Foundation

struct ConversationListResponseDTO: Codable {
    let items: [ConversationDTO]
    let nextCursor: String?
}

struct ConversationDTO: Codable {
    let id: Int
    let otherUserProfile: ConversationUserProfileDTO
    let lastMessage: String?
    let lastMessageTimestamp: Date?
    let unreadCount: Int
}

struct ConversationUserProfileDTO: Codable {
    let id: Int
    let handle: String
    let displayName: String?
    let profileImageUrl: String?
}

struct MessageListResponseDTO: Codable {
    let items: [MessageDTO]
    let nextCursor: String?
}

struct MessageDTO: Codable {
    let id: Int
    let senderId: Int
    let content: String
    let attachments: [MediaAttachmentDTO]?
    let createdAt: Date
}

struct ChannelListResponseDTO: Codable {
    let items: [ChannelDTO]
    let nextCursor: String?
}

struct ChannelDTO: Codable {
    let id: Int
    let name: String
    let memberCount: Int
    let isPublic: Bool
    let createdAt: Date
}

struct SendMessageRequestDTO: Codable {
    let content: String
    let attachments: [MediaAttachmentDTO]?
}

struct MediaAttachmentDTO: Codable {
    let url: String
    let thumbnailUrl: String?
    let type: String?
    let width: Int?
    let height: Int?
    let durationSeconds: Double?
    let sizeBytes: Int64?
}
