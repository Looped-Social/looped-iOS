import Foundation

struct NotificationListResponseDTO: Codable {
    let items: [NotificationDTO]
    let nextCursor: String?
}

struct NotificationDTO: Codable {
    let id: Int
    let type: String
    let actorId: Int
    let actorName: String
    let actorProfileImageUrl: String?
    let targetId: Int?
    let targetContent: String?
    let isRead: Bool
    let createdAt: Date
}
