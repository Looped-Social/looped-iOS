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
    let kind: String?
    let actorPrincipalId: Int?
    let actorUserId: Int?
    let actorAnonProfileId: Int?
    let actorIsAnonymous: Bool?
    let actorDisplayName: String?
    let actorProfileImageUrl: String?
    let conversationId: Int?
    let messageId: Int?
    let postId: Int?
    let commentId: Int?
    let context: String?
    let title: String?
    let body: String?
    let years: Int?
    let deeplink: String?
    let actionDeeplink: String?
    let companyId: Int?
}
