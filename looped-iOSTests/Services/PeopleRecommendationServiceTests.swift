import Foundation
import Testing
@testable import looped_iOS

private final class PeopleRecommendationURLProtocol: URLProtocol {
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

private struct PeopleRecommendationStaticTokenProvider: AuthTokenProvider {
    let token: String
    func currentIDToken() async throws -> String? { token }
}

@Suite(.serialized)
struct PeopleRecommendationServiceTests {
    @Test
    func fetchRails_mapsBundleAndEncodesQuery() async throws {
        PeopleRecommendationURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/v1/recommendations/people/rails")
            let query = request.url?.query ?? ""
            #expect(query.contains("surface=search"))
            #expect(query.contains("rails=pymk,community") || query.contains("rails=pymk%2Ccommunity"))
            #expect(query.contains("limit_per_rail=10"))
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
            return makeResponse(
                for: request,
                body: """
                {
                  "request_id": "req_rails_1",
                  "surface": "search",
                  "community": { "id": 7, "name": "UNC" },
                  "rails": [
                    {
                      "rail": "pymk",
                      "title": "People You May Know",
                      "items": [
                        {
                          "recommendation_id": "rec_1",
                          "user": {
                            "id": 901,
                            "handle": "looped901",
                            "display_name": null,
                            "avatar_url": "https://cdn.example.com/a.jpg",
                            "headline": "Product @ UNC",
                            "community": { "id": 7, "name": "UNC" }
                          },
                          "reasons": [{ "code": "mutuals", "text": "3 mutuals" }],
                          "actions": { "can_connect": true, "can_hide": true, "can_less_like_this": true },
                          "tracking": { "token": "trk_1", "position": 1 }
                        }
                      ],
                      "next_cursor": "cursor-1",
                      "has_more": true,
                      "degraded": false
                    }
                  ],
                  "experiment": { "key": "rec_search", "bucket": "B" },
                  "degraded": false,
                  "generated_at": "2026-02-24T12:00:00Z"
                }
                """
            )
        }
        defer { PeopleRecommendationURLProtocol.requestHandler = nil }

        let service = makeService()
        let bundle = try await service.fetchRails(
            surface: .search,
            communityId: nil,
            rails: [.pymk, .community],
            limitPerRail: 10
        )

        #expect(bundle.requestId == "req_rails_1")
        #expect(bundle.surface == .search)
        #expect(bundle.community?.id == 7)
        #expect(bundle.rails.count == 1)
        #expect(bundle.rails.first?.rail == .pymk)
        #expect(bundle.rails.first?.items.first?.recommendationId == "rec_1")
        #expect(bundle.rails.first?.items.first?.user.id == 901)
        #expect(bundle.rails.first?.items.first?.user.displayName == "looped901")
        #expect(bundle.rails.first?.items.first?.tracking.token == "trk_1")
        #expect(bundle.experiment?.bucket == "B")
    }

    @Test
    func fetchRail_mapsPageAndPassesCursor() async throws {
        PeopleRecommendationURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/v1/recommendations/people/pymk")
            let query = request.url?.query ?? ""
            #expect(query.contains("surface=search"))
            #expect(query.contains("limit=20"))
            #expect(query.contains("cursor=opaque-cursor"))
            return makeResponse(
                for: request,
                body: """
                {
                  "request_id": "req_rail_1",
                  "rail": "pymk",
                  "title": "People You May Know",
                  "items": [],
                  "next_cursor": "cursor-2",
                  "has_more": true,
                  "degraded": false
                }
                """
            )
        }
        defer { PeopleRecommendationURLProtocol.requestHandler = nil }

        let service = makeService()
        let page = try await service.fetchRail(
            rail: .pymk,
            surface: .search,
            communityId: nil,
            limit: 20,
            cursor: "opaque-cursor"
        )

        #expect(page.requestId == "req_rail_1")
        #expect(page.rail == .pymk)
        #expect(page.nextCursor == "cursor-2")
        #expect(page.hasMore == true)
    }

    @Test
    func sendFeedback_postsEventsAndReturnsSuppressedCandidateIds() async throws {
        PeopleRecommendationURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/v1/recommendations/people/feedback")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            let data = request.httpBody ?? Data()
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let events = object?["events"] as? [[String: Any]]
            #expect(events?.count == 1)
            #expect(events?.first?["type"] as? String == "hide")
            #expect(events?.first?["recommendation_id"] as? String == "rec_1")
            #expect(events?.first?["tracking_token"] as? String == "trk_1")

            return makeResponse(
                for: request,
                body: """
                {
                  "request_id": "req_feedback_1",
                  "accepted": 1,
                  "deduped": 0,
                  "dropped": 0,
                  "suppressed_candidate_ids": [901]
                }
                """
            )
        }
        defer { PeopleRecommendationURLProtocol.requestHandler = nil }

        let service = makeService()
        let response = try await service.sendFeedback(
            events: [
                PeopleRecommendationFeedbackEvent(
                    eventId: "event-1",
                    type: .hide,
                    recommendationId: "rec_1",
                    trackingToken: "trk_1",
                    position: 1
                )
            ]
        )

        #expect(response.requestId == "req_feedback_1")
        #expect(response.accepted == 1)
        #expect(response.suppressedCandidateIds == [901])
    }
}

private func makeService() -> PeopleRecommendationService {
    let apiClient = APIClient(
        baseURL: "https://example.com",
        session: makeSession(),
        tokenStorage: TokenStorage(),
        tokenProvider: PeopleRecommendationStaticTokenProvider(token: "jwt-token")
    )
    return PeopleRecommendationService(apiClient: apiClient)
}

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [PeopleRecommendationURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeResponse(for request: URLRequest, body: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    return (response, Data(body.utf8))
}
