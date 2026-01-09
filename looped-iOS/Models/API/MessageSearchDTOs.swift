import Foundation

struct MessageSearchResponseDTO: Codable {
    let items: [MessageSearchHitDTO]
    let nextCursor: String?
}

struct MessageSearchHitDTO: Codable {
    let type: String

    // Conversation hit fields
    let conversationId: Int?
    let otherUserProfile: ConversationUserProfileDTO?

    // Channel hit fields
    let channelId: Int?
    let name: String?
    let isPublic: Bool?

    // Common fields
    let lastMessage: String?
    let lastMessageTimestamp: Date?
    let matchedMessage: MessageDTO?
}

