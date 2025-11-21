import Foundation

class NotificationService: NotificationServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func fetchNotifications(limit: Int, cursor: String?) async throws -> NotificationPage {
        var endpoint = "/v1/notifications?limit=\(limit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: NotificationListResponseDTO = try await apiClient.get(endpoint)
        let notifications = response.items.map { dto in
            Notification(
                id: UUID.fromBackendId(dto.id),
                type: NotificationType(rawValue: dto.type) ?? .like,
                actorId: UUID.fromBackendId(dto.actorId),
                actorName: dto.actorName,
                actorProfileImageUrl: dto.actorProfileImageUrl,
                additionalActors: nil,
                targetId: dto.targetId.map(UUID.fromBackendId),
                targetContent: dto.targetContent,
                isRead: dto.isRead,
                createdAt: dto.createdAt
            )
        }
        return NotificationPage(notifications: notifications, nextCursor: response.nextCursor)
    }
    
    func markRead(notificationId: Int) async throws {
        struct MarkReadResponse: Codable { let read: Bool }
        let _: MarkReadResponse = try await apiClient.post("/v1/notifications/\(notificationId)/read", body: EmptyBody())
    }
}

private struct EmptyBody: Codable {}
