import Foundation

struct NotificationListResponseDTO: Codable {
    let items: [NotificationDTO]
    let nextCursor: String?
}

struct NotificationDTO: Codable {
    let id: Int
    let type: String
    let createdAt: Date
    let unread: Bool
    let payload: NotificationPayloadDTO?
}

struct NotificationPayloadDTO: Codable {
    let actorPrincipalId: String?
    let actorUserId: Int?
    let actorIsAnonymous: Bool?
    let postId: Int?
    let commentId: Int?
    let context: String?
    let title: String?
    let body: String?
    let deeplink: String?
    let companyId: Int?
}
