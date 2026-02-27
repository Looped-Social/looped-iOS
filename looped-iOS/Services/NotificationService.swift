import Foundation

class NotificationService: NotificationServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func fetchNotifications(limit: Int, cursor: String?) async throws -> NotificationPage {
        try await fetchNotifications(limit: limit, cursor: cursor, includeDismissed: false)
    }

    func fetchNotifications(limit: Int, cursor: String?, includeDismissed: Bool) async throws -> NotificationPage {
        var endpoint = "/v1/notifications?limit=\(limit)"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        if includeDismissed {
            endpoint += "&includeDismissed=true"
        }
        let response: NotificationListResponseDTO = try await apiClient.get(endpoint)
        let notifications: [Notification] = response.items.map { dto -> Notification in
            let normalizedType = dto.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let type = NotificationType(rawValue: normalizedType) ?? .system
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
            let deeplink = payload?.deeplink ?? payload?.actionDeeplink
            let actionDeeplink = payload?.actionDeeplink ?? payload?.deeplink
            let fallbackDeeplink = payload?.fallbackDeeplink
            let privacyLevel: NotificationPrivacyLevel? = {
                let trimmed = (payload?.privacyLevel ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !trimmed.isEmpty else { return nil }
                return NotificationPrivacyLevel(rawValue: trimmed)
            }()
            let announcementKind: NotificationAnnouncementKind? = {
                guard let rawKind = payload?.kind?.trimmingCharacters(in: .whitespacesAndNewlines), !rawKind.isEmpty else {
                    return nil
                }
                return NotificationAnnouncementKind(rawValue: rawKind.lowercased())
            }()
            return Notification(
                id: UUID.fromBackendId(dto.id),
                notificationUUID: dto.notificationId ?? payload?.notificationId,
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
                category: payload?.category,
                verificationKind: payload?.kind,
                verificationStatus: payload?.status,
                verificationMethod: payload?.method,
                verificationCommunityId: payload?.communityId ?? payload?.companyId,
                verificationCommunityName: payload?.communityName,
                verificationExpiresAt: parseISODate(payload?.expiresAt),
                verificationDaysRemaining: payload?.daysRemaining,
                verificationEventKey: payload?.eventKey,
                verificationRejectReason: payload?.rejectReason,
                announcementKind: announcementKind,
                announcementYears: payload?.years,
                deeplink: deeplink,
                actionDeeplink: actionDeeplink,
                fallbackDeeplink: fallbackDeeplink,
                privacyLevel: privacyLevel,
                reason: payload?.reason,
                newPostsCount: payload?.newPostsCount,
                since: payload?.since,
                communityId: payload?.communityId,
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

    func dismiss(notificationId: Int) async throws {
        struct DismissResponse: Codable { let dismissed: Bool }
        let _: DismissResponse = try await apiClient.post("/v1/notifications/\(notificationId)/dismiss", body: EmptyBody())
    }

    func dismissAll() async throws -> Int {
        struct DismissAllResponse: Codable { let dismissedCount: Int }
        let response: DismissAllResponse = try await apiClient.post("/v1/notifications/dismiss-all", body: EmptyBody())
        return max(0, response.dismissedCount)
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

    func parseISODate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = Self.iso8601WithFractional.date(from: value) {
            return date
        }
        return Self.iso8601.date(from: value)
    }

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
