import Foundation
import Testing
@testable import looped_iOS

private final class FeedServiceTrendingURLProtocol: URLProtocol {
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

private struct FeedServiceTrendingTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? { token }
}

@Suite(.serialized)
struct FeedServiceTrendingTests {
    @Test
    func fetchTrendingPosts_clampsLimit_encodesOpaqueCursor_andMapsPayload() async throws {
        var capturedRequest: URLRequest?
        FeedServiceTrendingURLProtocol.requestHandler = { request in
            capturedRequest = request
            let json = """
            {
              "feed_request_id": "2f247977-6404-4a31-a5f9-808f4f7428e0",
              "algorithm": "trending_personal_v1",
              "algorithm_version": "1",
              "items": [
                {
                  "id": 1001,
                  "company_id": 40,
                  "community_id": 77,
                  "content": "Personalized trending post",
                  "likes_count": 17,
                  "comments_count": 3,
                  "created_at": "2026-02-22T18:20:00Z",
                  "author_display_name": "Taylor",
                  "community_name": "Product",
                  "community_short_name": "Prod",
                  "community_kind": "specialization"
                }
              ],
              "next_cursor": "opaque-next"
            }
            """
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
        defer { FeedServiceTrendingURLProtocol.requestHandler = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FeedServiceTrendingURLProtocol.self]
        let session = URLSession(configuration: config)
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: FeedServiceTrendingTokenProvider(token: "jwt-token")
        )
        let service = FeedService(apiClient: apiClient)

        let posts = try await service.fetchTrendingPosts(limit: 99, cursor: "a+b/c=d?", communityId: 77)

        #expect(capturedRequest?.httpMethod == "GET")
        #expect(capturedRequest?.url?.path == "/v1/feed/trending")
        #expect(capturedRequest?.url?.query?.contains("limit=50") == true)
        #expect(capturedRequest?.url?.query?.contains("cursor=a%2Bb%2Fc%3Dd%3F") == true)
        #expect(capturedRequest?.url?.query?.contains("communityId=77") == true)
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")

        #expect(posts.count == 1)
        #expect(posts.first?.id == 1001)
        #expect(posts.first?.title == "Personalized trending post")
        #expect(posts.first?.authorDisplayName == "Taylor")
        #expect(posts.first?.subtitle == "Trending in Product")
    }
}
