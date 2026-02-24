import Foundation
import Testing
@testable import looped_iOS

private final class FeedServiceUpdatePostURLProtocol: URLProtocol {
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

private struct FeedServiceUpdatePostTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? { token }
}

@Suite(.serialized)
struct FeedServiceUpdatePostTests {
    @Test
    func updatePost_withRemoveMedia_sendsFlagAndMapsResponse() async throws {
        var capturedRequest: URLRequest?

        FeedServiceUpdatePostURLProtocol.requestHandler = { request in
            capturedRequest = request
            let json = """
            {
              "id": 55,
              "content": "Updated text",
              "media_asset_id": null,
              "media_asset_ids": null,
              "community_id": 77,
              "community_name": "UNC",
              "community_kind": "school",
              "created_at": "2026-02-23T18:20:00Z"
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
        defer { FeedServiceUpdatePostURLProtocol.requestHandler = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FeedServiceUpdatePostURLProtocol.self]
        let session = URLSession(configuration: config)
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: FeedServiceUpdatePostTokenProvider(token: "jwt-token")
        )
        let service = FeedService(apiClient: apiClient)

        let post = try await service.updatePost(
            postId: 55,
            content: "Updated text",
            isAnonymous: false,
            communityId: 77,
            removeMedia: true
        )

        #expect(capturedRequest?.httpMethod == "PUT")
        #expect(capturedRequest?.url?.path == "/v1/posts/55")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")

        let body = try decodeRequestBody(from: capturedRequest)
        #expect(body["content"] as? String == "Updated text")
        #expect(body["removeMedia"] as? Bool == true)
        #expect(body["asAnon"] == nil)

        #expect(post.backendId == 55)
        #expect(post.content == "Updated text")
        #expect(post.mediaAssetId == nil)
        #expect(post.mediaAssetIds == nil)
    }
}

private func decodeRequestBody(from request: URLRequest?) throws -> [String: Any] {
    guard let request, let data = requestBodyData(from: request) else {
        throw APIError.invalidResponse
    }
    let raw = try JSONSerialization.jsonObject(with: data)
    guard let json = raw as? [String: Any] else {
        throw APIError.invalidResponse
    }
    return json
}

private func requestBodyData(from request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: bufferSize)
        if read < 0 {
            return nil
        }
        if read == 0 {
            break
        }
        data.append(buffer, count: read)
    }
    return data
}
