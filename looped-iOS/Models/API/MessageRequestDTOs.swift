import Foundation

struct MessageRequestListResponseDTO: Decodable {
    let items: [MessageRequestDTO]
    let nextCursor: String?
}

struct MessageRequestDTO: Decodable {
    let id: Int
    let status: MessageRequestStatus?
    let senderId: Int?
    let preview: MessagePreviewDTO?
    let conversationId: Int?
    let channelId: Int?
    let isGroup: Bool?
    let senderProfile: ConversationUserProfileDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resolvedId = try container.decodeIfPresent(Int.self, forKey: .id)
            ?? container.decodeIfPresent(Int.self, forKey: .requestId)
            ?? container.decodeIfPresent(Int.self, forKey: .messageRequestId)

        guard let resolvedId else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing message request id")
            )
        }

        let status = try container.decodeIfPresent(MessageRequestStatus.self, forKey: .status)
        let senderProfile = try container.decodeIfPresent(ConversationUserProfileDTO.self, forKey: .senderProfile)
            ?? container.decodeIfPresent(ConversationUserProfileDTO.self, forKey: .requesterProfile)
            ?? container.decodeIfPresent(ConversationUserProfileDTO.self, forKey: .sender)
            ?? container.decodeIfPresent(ConversationUserProfileDTO.self, forKey: .userProfile)
            ?? container.decodeIfPresent(ConversationUserProfileDTO.self, forKey: .otherUserProfile)

        var preview = try container.decodeIfPresent(MessagePreviewDTO.self, forKey: .preview)
            ?? container.decodeIfPresent(MessagePreviewDTO.self, forKey: .message)

        var senderId = try container.decodeIfPresent(Int.self, forKey: .senderId)
        if senderId == nil {
            senderId = try container.decodeIfPresent(Int.self, forKey: .requesterId)
        }
        if senderId == nil {
            senderId = preview?.senderId ?? senderProfile?.id
        }

        if preview == nil,
           let content = try container.decodeIfPresent(String.self, forKey: .content),
           let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt),
           let resolvedSenderId = senderId {
            let attachments = try container.decodeIfPresent([MediaAttachmentDTO].self, forKey: .attachments)
            preview = MessagePreviewDTO(
                id: resolvedId,
                senderId: resolvedSenderId,
                content: content,
                attachments: attachments,
                createdAt: createdAt
            )
        }

        self.id = resolvedId
        self.status = status
        self.senderId = senderId
        self.preview = preview
        self.conversationId = try container.decodeIfPresent(Int.self, forKey: .conversationId)
        self.channelId = try container.decodeIfPresent(Int.self, forKey: .channelId)
        self.isGroup = try container.decodeIfPresent(Bool.self, forKey: .isGroup)
        self.senderProfile = senderProfile
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case requestId
        case messageRequestId
        case senderId
        case requesterId
        case status
        case preview
        case message
        case content
        case attachments
        case createdAt
        case conversationId
        case channelId
        case isGroup
        case senderProfile
        case requesterProfile
        case sender
        case userProfile
        case otherUserProfile
    }
}

struct MessagePreviewDTO: Decodable {
    let id: Int
    let senderId: Int
    let content: String
    let attachments: [MediaAttachmentDTO]?
    let createdAt: Date
}
