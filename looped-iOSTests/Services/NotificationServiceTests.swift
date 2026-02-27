import Foundation
import Testing
@testable import looped_iOS

private final class NotificationRequestCaptureURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class NotificationRequestBox {
    var request: URLRequest?
}

private struct NotificationStaticTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? {
        token
    }
}

@Suite(.serialized)
struct NotificationServiceTests {
    @Test
    func fetchNotifications_mapsVerificationAnnouncementPayloadAndNormalizesDeeplinkAliases() async throws {
        let requestBox = NotificationRequestBox()
        NotificationRequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            return makeNotificationResponse(for: request)
        }
        defer { NotificationRequestCaptureURLProtocol.requestHandler = nil }

        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: makeNotificationsSession(),
            tokenStorage: TokenStorage(),
            tokenProvider: NotificationStaticTokenProvider(token: "jwt-token")
        )
        let service = NotificationService(apiClient: apiClient)

        let page = try await service.fetchNotifications(limit: 20, cursor: nil)

        guard let request = requestBox.request else {
            Issue.record("Expected captured request for notifications")
            return
        }
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/v1/notifications")
        #expect(request.url?.query?.contains("limit=20") == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")

        #expect(page.nextCursor == "cursor-2")
        #expect(page.notifications.count == 1)
        guard page.notifications.count == 1 else {
            Issue.record("Expected one decoded notification")
            return
        }

        let notification = page.notifications[0]
        #expect(notification.id.backendInt == 991)
        #expect(notification.notificationUUID == nil)
        #expect(notification.type == .announcement)
        #expect(notification.actorId == nil)
        #expect(notification.actorAnonProfileId == nil)
        #expect(notification.actorName == "Looped")
        #expect(notification.verificationKind == "community_verification")
        #expect(notification.verificationStatus == "rejected")
        #expect(notification.verificationCommunityId == 77)
        #expect(notification.verificationCommunityName == "Acme")
        #expect(notification.verificationRejectReason == "Use your work email.")
        #expect(notification.notificationText == "Verification rejected")
        #expect(notification.previewText == "Unable to verify your Acme email.")
        #expect(notification.deeplink == "looped://verification/community/77")
        #expect(notification.actionDeeplink == "looped://verification/community/77")
    }

    @Test
    func verificationRendering_requiresAnnouncementKindAndStatus() {
        let announcementWithKindOnly = Notification(
            type: .announcement,
            actorName: "Looped",
            title: nil,
            body: nil,
            verificationKind: "user_verification",
            verificationStatus: nil
        )
        #expect(announcementWithKindOnly.notificationText == "Looped posted an announcement")

        let announcementWithKindAndStatus = Notification(
            type: .announcement,
            actorName: "Looped",
            title: nil,
            body: nil,
            verificationKind: "user_verification",
            verificationStatus: "approved"
        )
        #expect(announcementWithKindAndStatus.notificationText == "You're verified")
        #expect(announcementWithKindAndStatus.previewText == "Your verification is approved.")

        let systemWithVerificationMetadata = Notification(
            type: .system,
            actorName: "System",
            title: nil,
            body: nil,
            verificationKind: "user_verification",
            verificationStatus: "approved"
        )
        #expect(systemWithVerificationMetadata.notificationText == "System notification")
    }

    @Test
    func fetchNotifications_mapsNewTypesAndUuidAndFallbackDeeplink() async throws {
        let requestBox = NotificationRequestBox()
        NotificationRequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(
                """
                {
                  "items": [
                    {
                      "id": 123,
                      "notification_id": "00000000-0000-0000-0000-000000000001",
                      "type": "since_away_highlights",
                      "created_at": "2026-02-27T18:14:00Z",
                      "unread": true,
                      "payload": {
                        "deeplink": "looped://feed",
                        "privacy_level": "generic",
                        "new_posts_count": 7,
                        "since": "2026-02-27T17:00:00Z"
                      }
                    },
                    {
                      "id": 124,
                      "notification_id": "00000000-0000-0000-0000-000000000002",
                      "type": "trending_today",
                      "created_at": "2026-02-27T18:15:00Z",
                      "unread": true,
                      "payload": {
                        "post_id": 55,
                        "community_id": 42,
                        "deeplink": "looped://post/55",
                        "fallback_deeplink": "looped://feed?tab=trending&community_id=42",
                        "privacy_level": "detailed",
                        "reason": { "score": 1.2, "window": "today" }
                      }
                    }
                  ],
                  "next_cursor": null
                }
                """.utf8
            )
            return (response, data)
        }
        defer { NotificationRequestCaptureURLProtocol.requestHandler = nil }

        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: makeNotificationsSession(),
            tokenStorage: TokenStorage(),
            tokenProvider: NotificationStaticTokenProvider(token: "jwt-token")
        )
        let service = NotificationService(apiClient: apiClient)

        let page = try await service.fetchNotifications(limit: 50, cursor: nil)
        #expect(page.notifications.count == 2)

        let highlights = page.notifications[0]
        #expect(highlights.type == .sinceAwayHighlights)
        #expect(highlights.notificationUUID?.uuidString.lowercased() == "00000000-0000-0000-0000-000000000001")
        #expect(highlights.deeplink == "looped://feed")
        #expect(highlights.newPostsCount == 7)
        #expect(highlights.privacyLevel == .generic)

        let trending = page.notifications[1]
        #expect(trending.type == .trendingToday)
        #expect(trending.notificationUUID?.uuidString.lowercased() == "00000000-0000-0000-0000-000000000002")
        #expect(trending.targetId?.backendInt == 55)
        #expect(trending.communityId == 42)
        #expect(trending.fallbackDeeplink == "looped://feed?tab=trending&community_id=42")
        #expect(trending.privacyLevel == .detailed)
    }
}

private func makeNotificationsSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [NotificationRequestCaptureURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeNotificationResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    let data = Data(
        """
        {
          "items": [
            {
              "id": 991,
              "type": "announcement",
              "created_at": "2026-02-19T01:02:03Z",
              "unread": true,
              "payload": {
                "category": "verification",
                "kind": "community_verification",
                "status": "rejected",
                "community_id": 77,
                "community_name": "Acme",
                "reject_reason": "Use your work email.",
                "title": "Verification rejected",
                "body": "Unable to verify your Acme email.",
                "action_deeplink": "looped://verification/community/77",
                "event_key": "verification.community.rejected"
              }
            }
          ],
          "next_cursor": "cursor-2"
        }
        """.utf8
    )
    return (response, data)
}
