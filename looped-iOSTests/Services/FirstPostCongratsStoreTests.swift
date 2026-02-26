import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
struct FeedServiceCreatePostMilestonesTests {

    @Test
    func createPost_mapsMilestonesAwarded() async throws {
        var capturedRequest: URLRequest?

        FeedServiceCreatePostMilestonesURLProtocol.requestHandler = { request in
            capturedRequest = request
            let json = """
            {
              "id": 55,
              "content": "Hello world",
              "community_id": 77,
              "community_name": "Product",
              "community_kind": "specialization",
              "created_at": "2026-02-26T18:20:00Z",
              "milestones_awarded": ["first_post_ever"]
            }
            """
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(json.utf8))
        }
        defer { FeedServiceCreatePostMilestonesURLProtocol.requestHandler = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FeedServiceCreatePostMilestonesURLProtocol.self]
        let session = URLSession(configuration: config)
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: FeedServiceCreatePostMilestonesTokenProvider(token: "jwt-token")
        )
        let service = FeedService(apiClient: apiClient)

        let post = try await service.createPost(
            content: "Hello world",
            isAnonymous: false,
            communityId: 77,
            mediaAssetId: nil,
            mediaAssetIds: nil,
            poll: nil
        )

        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.url?.path == "/v1/posts")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Idempotency-Key")?.isEmpty == false)

        #expect(post.backendId == 55)
        #expect(post.awardedMilestones?.contains("first_post_ever") == true)
    }
}

private final class FeedServiceCreatePostMilestonesURLProtocol: URLProtocol {
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

private struct FeedServiceCreatePostMilestonesTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? { token }
}
