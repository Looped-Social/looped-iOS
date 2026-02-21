import Foundation
import Testing
@testable import looped_iOS

private final class FeedServiceRepostersURLProtocol: URLProtocol {
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

private struct FeedServiceStaticTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? { token }
}

@Suite(.serialized)
struct FeedServiceRepostersTests {
    @Test
    func fetchReposters_requestsEndpointAndMapsPayload() async throws {
        var capturedRequest: URLRequest?
        FeedServiceRepostersURLProtocol.requestHandler = { request in
            capturedRequest = request
            let json = """
            {
              "items": [
                {
                  "repost_id": 900,
                  "reposted_at": "2026-02-21T18:20:00Z",
                  "user_id": 123,
                  "username": "luke",
                  "display_name": "Luke Miller",
                  "handle": "luke",
                  "profile_image_url": "https://cdn.example.com/avatar.jpg"
                }
              ],
              "next_cursor": "cursor-2"
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
        defer { FeedServiceRepostersURLProtocol.requestHandler = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FeedServiceRepostersURLProtocol.self]
        let session = URLSession(configuration: config)
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: FeedServiceStaticTokenProvider(token: "jwt-token")
        )
        let service = FeedService(apiClient: apiClient)

        let page = try await service.fetchReposters(postId: 55, limit: 500, cursor: "abc def")

        #expect(capturedRequest?.httpMethod == "GET")
        #expect(capturedRequest?.url?.path == "/v1/posts/55/reposters")
        #expect(capturedRequest?.url?.query?.contains("limit=100") == true)
        #expect(capturedRequest?.url?.query?.contains("cursor=abc%20def") == true)
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")

        #expect(page.items.count == 1)
        #expect(page.items[0].repostId == 900)
        #expect(page.items[0].displayName == "Luke Miller")
        #expect(page.items[0].handle == "luke")
        #expect(page.items[0].profileImageURL == "https://cdn.example.com/avatar.jpg")
        #expect(page.nextCursor == "cursor-2")
    }
}
