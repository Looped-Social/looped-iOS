import Foundation

enum MessageRequestStatus: String, Codable {
    case pending
    case approved
    case rejected
}

struct MessageRequest: Identifiable {
    let id: UUID
    let backendId: Int
    let senderBackendId: Int?
    let senderName: String?
    let senderHandle: String?
    let senderProfileImageUrl: String?
    let previewText: String
    let previewAttachments: [MediaAttachment]
    let previewCreatedAt: Date
    let status: MessageRequestStatus
    let conversationBackendId: Int?
    let channelBackendId: Int?
    let isGroup: Bool

    init(
        id: UUID = UUID(),
        backendId: Int,
        senderBackendId: Int?,
        senderName: String?,
        senderHandle: String?,
        senderProfileImageUrl: String?,
        previewText: String,
        previewAttachments: [MediaAttachment],
        previewCreatedAt: Date,
        status: MessageRequestStatus,
        conversationBackendId: Int?,
        channelBackendId: Int?,
        isGroup: Bool
    ) {
        self.id = id
        self.backendId = backendId
        self.senderBackendId = senderBackendId
        self.senderName = senderName
        self.senderHandle = senderHandle
        self.senderProfileImageUrl = senderProfileImageUrl
        self.previewText = previewText
        self.previewAttachments = previewAttachments
        self.previewCreatedAt = previewCreatedAt
        self.status = status
        self.conversationBackendId = conversationBackendId
        self.channelBackendId = channelBackendId
        self.isGroup = isGroup
    }
}

struct MessageRequestPage {
    let requests: [MessageRequest]
    let nextCursor: String?
}

extension MessageRequest {
    var displayName: String {
        if let senderName, !senderName.isEmpty {
            return senderName
        }
        if let senderHandle, !senderHandle.isEmpty {
            return senderHandle
        }
        return "Anonymous"
    }

    var previewSummary: String {
        let trimmed = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if !previewAttachments.isEmpty {
            return "Sent an attachment"
        }
        return "Sent a message"
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDate(previewCreatedAt, inSameDayAs: Date()) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: previewCreatedAt)
        } else if calendar.isDate(previewCreatedAt, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "M/d"
            return formatter.string(from: previewCreatedAt)
        } else {
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: previewCreatedAt)
        }
    }

    func updatingSender(name: String, profileImageUrl: String?) -> MessageRequest {
        MessageRequest(
            id: id,
            backendId: backendId,
            senderBackendId: senderBackendId,
            senderName: name,
            senderHandle: senderHandle,
            senderProfileImageUrl: profileImageUrl,
            previewText: previewText,
            previewAttachments: previewAttachments,
            previewCreatedAt: previewCreatedAt,
            status: status,
            conversationBackendId: conversationBackendId,
            channelBackendId: channelBackendId,
            isGroup: isGroup
        )
    }
}
