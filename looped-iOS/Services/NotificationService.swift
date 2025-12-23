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
        let notifications: [Notification] = response.items.map { dto -> Notification in
            let type = NotificationType(rawValue: dto.type) ?? .like
            let payload = dto.payload
            let actorIsAnonymous = payload?.actorIsAnonymous ?? (payload?.actorUserId == nil)
            let actorId = actorIsAnonymous ? nil : payload?.actorUserId.map(UUID.fromBackendId)
            let actorName = defaultActorName(for: type, isAnonymous: actorIsAnonymous)
            let mentionContext = payload?.context.flatMap(NotificationMentionContext.init(rawValue:))
            let targetIdValue = payload?.postId ?? payload?.commentId
            return Notification(
                id: UUID.fromBackendId(dto.id),
                type: type,
                actorId: actorId,
                actorName: actorName,
                actorProfileImageUrl: nil,
                actorIsAnonymous: actorIsAnonymous,
                additionalActors: nil,
                targetId: targetIdValue.map(UUID.fromBackendId),
                targetCommentId: payload?.commentId.map(UUID.fromBackendId),
                targetContent: nil,
                title: payload?.title,
                body: payload?.body,
                deeplink: payload?.deeplink,
                mentionContext: mentionContext,
                isRead: !dto.unread,
                createdAt: dto.createdAt
            )
        }
        return NotificationPage(notifications: notifications, nextCursor: response.nextCursor)
    }
    
    func markRead(notificationId: Int) async throws {
        struct MarkReadResponse: Codable { let read: Bool }
        let _: MarkReadResponse = try await apiClient.post("/v1/notifications/\(notificationId)/read", body: EmptyBody())
    }

    func fetchPreferences() async throws -> NotificationPreferencesDTO {
        let response: NotificationPreferencesResponseDTO = try await apiClient.get("/v1/notifications/preferences")
        return response.notifications
    }

    func updatePreferences(_ update: NotificationPreferencesUpdateRequest) async throws -> NotificationPreferencesDTO {
        let response: NotificationPreferencesResponseDTO = try await apiClient.put("/v1/notifications/preferences", body: update)
        return response.notifications
    }
}

private struct EmptyBody: Codable {}

private extension NotificationService {
    func defaultActorName(for type: NotificationType, isAnonymous: Bool) -> String {
        switch type {
        case .announcement:
            return "Looped"
        case .system:
            return "System"
        default:
            return isAnonymous ? "Anonymous" : "Someone"
        }
    }
}
