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
            let type = NotificationType(rawValue: dto.type) ?? .system
            let payload = dto.payload
            let actorIsAnonymous = payload?.actorIsAnonymous
                ?? (payload?.actorUserId == nil && payload?.actorAnonProfileId != nil)
            let actorId = actorIsAnonymous ? nil : payload?.actorUserId.map(UUID.fromBackendId)
            let actorAnonProfileId = actorIsAnonymous ? payload?.actorAnonProfileId.map(UUID.fromBackendId) : nil
            let actorName = resolvedActorName(
                payloadName: payload?.actorDisplayName,
                type: type,
                isAnonymous: actorIsAnonymous
            )
            let mentionContext = payload?.context.flatMap(NotificationMentionContext.init(rawValue:))
            let announcementKind: NotificationAnnouncementKind? = {
                guard let rawKind = payload?.kind?.trimmingCharacters(in: .whitespacesAndNewlines), !rawKind.isEmpty else {
                    return nil
                }
                return NotificationAnnouncementKind(rawValue: rawKind.lowercased())
            }()
            return Notification(
                id: UUID.fromBackendId(dto.id),
                type: type,
                actorId: actorId,
                actorAnonProfileId: actorAnonProfileId,
                actorName: actorName,
                actorProfileImageUrl: payload?.actorProfileImageUrl,
                actorIsAnonymous: actorIsAnonymous,
                additionalActors: nil,
                targetId: payload?.postId.map(UUID.fromBackendId),
                targetCommentId: payload?.commentId.map(UUID.fromBackendId),
                targetContent: nil,
                title: payload?.title,
                body: payload?.body,
                announcementKind: announcementKind,
                announcementYears: payload?.years,
                deeplink: payload?.deeplink,
                actionDeeplink: payload?.actionDeeplink,
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
    func resolvedActorName(payloadName: String?, type: NotificationType, isAnonymous: Bool) -> String {
        let trimmed = (payloadName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return defaultActorName(for: type, isAnonymous: isAnonymous)
    }

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
