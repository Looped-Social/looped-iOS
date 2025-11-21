import Foundation

struct Conversation: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let backendUserId: Int?
    let userName: String
    let userProfileImageUrl: String?
    let lastMessage: String
    let lastMessageTimestamp: Date
    let unreadCount: Int
    let hasTypingIndicator: Bool
    let hasSpecialStatus: Bool
    let isOnline: Bool
    let isGroup: Bool
    let memberIds: [UUID]?

    init(
        id: UUID = UUID(),
        userId: UUID,
        backendUserId: Int? = nil,
        userName: String,
        userProfileImageUrl: String? = nil,
        lastMessage: String,
        lastMessageTimestamp: Date,
        unreadCount: Int = 0,
        hasTypingIndicator: Bool = false,
        hasSpecialStatus: Bool = false,
        isOnline: Bool = false,
        isGroup: Bool = false,
        memberIds: [UUID]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.backendUserId = backendUserId
        self.userName = userName
        self.userProfileImageUrl = userProfileImageUrl
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.unreadCount = unreadCount
        self.hasTypingIndicator = hasTypingIndicator
        self.hasSpecialStatus = hasSpecialStatus
        self.isOnline = isOnline
        self.isGroup = isGroup
        self.memberIds = memberIds
    }
}

// MARK: - Convenience computed properties
extension Conversation {
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDate(lastMessageTimestamp, inSameDayAs: Date()) {
            formatter.dateFormat = "H:mm"
            return formatter.string(from: lastMessageTimestamp)
        } else if calendar.isDate(lastMessageTimestamp, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "d/M"
            return formatter.string(from: lastMessageTimestamp)
        } else {
            formatter.dateFormat = "d/M/yy"
            return formatter.string(from: lastMessageTimestamp)
        }
    }

    var hasUnreadMessages: Bool {
        return unreadCount > 0
    }
}
