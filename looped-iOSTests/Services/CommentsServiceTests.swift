import Foundation
import Testing
@testable import looped_iOS

private final class CommentsRequestCaptureURLProtocol: URLProtocol {
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

private final class CommentsRequestBox {
    var request: URLRequest?
}

private struct CommentsStaticTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? {
        token
    }
}

private struct CommentsNoopMediaService: MediaServiceProtocol {
    func uploadImage(data: Data, mimeType: String, width: Int, height: Int, actor: MediaUploadActor) async throws -> MediaAsset {
        throw APIError.invalidResponse
    }

    func uploadVideo(
        fileURL: URL,
        mimeType: String,
        width: Int,
        height: Int,
        durationSeconds: Int,
        actor: MediaUploadActor,
        thumbnailMediaAssetId: Int?
    ) async throws -> MediaAsset {
        throw APIError.invalidResponse
    }

    func resolvePublicMedia(ids: [Int]) async throws -> [MediaAsset] {
        []
    }
}

@Suite(.serialized)
struct CommentsServiceTests {
    private let anonymousModeKey = "anonymousMode"
    private let lastSelectedCommunityKey = "lastSelectedCommunityId"

    @Test
    func fetchComments_usesJwtAuthWithoutAnonProofInAnonymousMode() async throws {
        let requestBox = CommentsRequestBox()
        CommentsRequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            return makeCommentsResponse(for: request)
        }
        defer { CommentsRequestCaptureURLProtocol.requestHandler = nil }

        UserDefaults.standard.set(true, forKey: anonymousModeKey)
        UserDefaults.standard.set(77, forKey: lastSelectedCommunityKey)
        defer {
            UserDefaults.standard.removeObject(forKey: anonymousModeKey)
            UserDefaults.standard.removeObject(forKey: lastSelectedCommunityKey)
        }

        let session = makeCommentsSession()
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: CommentsStaticTokenProvider(token: "jwt-token")
        )
        let service = CommentsService(
            apiClient: apiClient,
            anonService: AnonService(apiClient: apiClient, store: AnonIdentityStore()),
            mediaService: CommentsNoopMediaService()
        )

        _ = try await service.fetchComments(postId: 55, communityId: 77, limit: 20, cursor: "abc+123")

        guard let request = requestBox.request else {
            Issue.record("Expected captured request for comments list")
            return
        }
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/v1/posts/55/comments")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
        #expect(request.value(forHTTPHeaderField: "X-Actor") == nil)
        #expect(request.url?.query?.contains("asAnon=") == false)
        #expect(request.url?.query?.contains("anonProfileId=") == false)
        #expect(request.url?.query?.contains("anonCert=") == false)
        #expect(request.url?.query?.contains("anonCertKid=") == false)
        #expect(request.url?.query?.contains("anonSig=") == false)
    }

    @Test
    func fetchReplies_usesJwtAuthWithoutAnonProofInAnonymousMode() async throws {
        let requestBox = CommentsRequestBox()
        CommentsRequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            return makeCommentsResponse(for: request)
        }
        defer { CommentsRequestCaptureURLProtocol.requestHandler = nil }

        UserDefaults.standard.set(true, forKey: anonymousModeKey)
        UserDefaults.standard.set(77, forKey: lastSelectedCommunityKey)
        defer {
            UserDefaults.standard.removeObject(forKey: anonymousModeKey)
            UserDefaults.standard.removeObject(forKey: lastSelectedCommunityKey)
        }

        let session = makeCommentsSession()
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: CommentsStaticTokenProvider(token: "jwt-token")
        )
        let service = CommentsService(
            apiClient: apiClient,
            anonService: AnonService(apiClient: apiClient, store: AnonIdentityStore()),
            mediaService: CommentsNoopMediaService()
        )

        _ = try await service.fetchReplies(commentId: 987, communityId: 77, limit: 20, cursor: nil)

        guard let request = requestBox.request else {
            Issue.record("Expected captured request for replies list")
            return
        }
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/v1/comments/987/replies")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
        #expect(request.value(forHTTPHeaderField: "X-Actor") == nil)
        #expect(request.url?.query?.contains("asAnon=") == false)
        #expect(request.url?.query?.contains("anonProfileId=") == false)
        #expect(request.url?.query?.contains("anonCert=") == false)
        #expect(request.url?.query?.contains("anonCertKid=") == false)
        #expect(request.url?.query?.contains("anonSig=") == false)
    }
}

private func makeCommentsSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CommentsRequestCaptureURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeCommentsResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
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
              "id": 1,
              "post_id": 55,
              "parent_id": null,
              "author": {
                "id": 2,
                "principal_id": 3,
                "is_anonymous": false,
                "display_name": "User",
                "username": "user",
                "handle": "user",
                "company_id": 77,
                "profile_image_url": null
              },
              "is_anonymous": false,
              "author_is_anonymous": false,
              "author_principal_id": 3,
              "content": "hello",
              "media_asset_id": null,
              "likes_count": 0,
              "reply_count": 0,
              "user_liked": false,
              "liked_by_creator": false,
              "is_deleted": false,
              "is_under_review": false,
              "created_at": "2026-02-17T19:19:23Z"
            }
          ],
          "next_cursor": null
        }
        """.utf8
    )
    return (response, data)
}
