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
    let createdAt: Date?
    let ownerUserId: Int?
    let viewerCanManageMembers: Bool?
}

struct SendMessageRequestDTO: Codable {
    let content: String
    let attachments: [MediaAttachmentDTO]?
}

struct CreateChannelRequestDTO: Codable {
    let name: String
    let memberUserIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case name
        case memberUserIds = "member_user_ids"
    }
}

struct ChannelMembersResponseDTO: Codable {
    let items: [ChannelMemberDTO]
    let nextCursor: String?
}

struct ChannelMemberDTO: Codable {
    let userId: Int
    let handle: String
    let displayName: String?
    let profileImageUrl: String?
    let companyId: Int
    let canManageMembers: Bool
    let createdAt: Date
    let isOwner: Bool
}

struct ChannelMembersAddRequestDTO: Codable {
    let userIds: [Int]

    enum CodingKeys: String, CodingKey {
        case userIds = "user_ids"
    }
}

struct ChannelMemberPermissionUpdateDTO: Codable {
    let canManageMembers: Bool

    enum CodingKeys: String, CodingKey {
        case canManageMembers = "can_manage_members"
    }
}

struct ChannelMembersAddResponseDTO: Codable {
    let status: String
    let addedCount: Int
}

struct ChannelMemberActionResponseDTO: Codable {
    let status: String
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
