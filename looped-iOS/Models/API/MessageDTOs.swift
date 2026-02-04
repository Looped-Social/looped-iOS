import Foundation

struct ConversationListResponseDTO: Codable {
    let items: [ConversationDTO]
    let nextCursor: String?
}

struct ConversationDTO: Codable {
    let id: Int
    let otherUserProfile: ConversationUserProfileDTO?
    let lastMessage: String?
    let lastMessageTimestamp: Date?
    let unreadCount: Int
    let muted: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case otherUserProfile
        case lastMessage
        case lastMessageTimestamp
        case unreadCount
        case muted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.otherUserProfile = try container.decodeIfPresent(ConversationUserProfileDTO.self, forKey: .otherUserProfile)
        self.lastMessage = try container.decodeIfPresent(String.self, forKey: .lastMessage)
        self.lastMessageTimestamp = try container.decodeIfPresent(Date.self, forKey: .lastMessageTimestamp)
        self.unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        self.muted = try container.decodeIfPresent(Bool.self, forKey: .muted) ?? false
    }
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
    let photoUrl: String?
    let muted: Bool?
}

struct SendMessageRequestDTO: Codable {
    let content: String
    let attachments: [SendMessageAttachmentDTO]?
}

struct SendMessageAttachmentDTO: Codable {
    let url: String
    let type: String?
    let width: Int?
    let height: Int?
    let durationSeconds: Int?
    let sizeBytes: Int64?
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case url
        case type
        case width
        case height
        case durationSeconds = "duration_seconds"
        case sizeBytes = "size_bytes"
        case thumbnailUrl = "thumbnail_url"
    }
}

struct CreateChannelRequestDTO: Codable {
    let name: String
    let memberUserIds: [Int]?
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
}

struct ChannelMemberPermissionUpdateDTO: Codable {
    let canManageMembers: Bool
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

    init(
        url: String,
        thumbnailUrl: String? = nil,
        type: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        durationSeconds: Double? = nil,
        sizeBytes: Int64? = nil
    ) {
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.type = type
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
        self.sizeBytes = sizeBytes
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let url = try? singleValue.decode(String.self) {
            self.init(url: url)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            url: try container.decode(String.self, forKey: .url),
            thumbnailUrl: try container.decodeIfPresent(String.self, forKey: .thumbnailUrl),
            type: try container.decodeIfPresent(String.self, forKey: .type),
            width: try container.decodeIfPresent(Int.self, forKey: .width),
            height: try container.decodeIfPresent(Int.self, forKey: .height),
            durationSeconds: try container.decodeIfPresent(Double.self, forKey: .durationSeconds),
            sizeBytes: try container.decodeIfPresent(Int64.self, forKey: .sizeBytes)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(sizeBytes, forKey: .sizeBytes)
    }

    private enum CodingKeys: String, CodingKey {
        case url
        case thumbnailUrl
        case type
        case width
        case height
        case durationSeconds
        case sizeBytes
    }
}
