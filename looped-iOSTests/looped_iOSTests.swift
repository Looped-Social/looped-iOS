//
//  looped_iOSTests.swift
//  looped-iOSTests
//
//  Created by William Millen on 9/5/25.
//

import Foundation
import Testing
@testable import looped_iOS

private final class RequestCaptureURLProtocol: URLProtocol {
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

private final class RequestBox {
    var request: URLRequest?
}

private struct StaticTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? {
        token
    }
}

@Suite(.serialized)
struct looped_iOSTests {

    @Test func messageSenderIdMatchesCurrentUserIdWhenSameBackendId() async throws {
        let backendUserId = 42
        let currentUser = User(
            id: UUID.fromBackendId(backendUserId),
            backendId: backendUserId,
            username: "you",
            displayName: "You",
            handle: "you",
            companyId: 1,
            companyName: "Looped",
            bio: nil,
            profileImageURL: nil,
            isVerified: true,
            isAnonymous: false,
            createdAt: nil,
            updatedAt: nil
        )

        let sentMessage = Message(
            id: UUID(),
            backendId: 1,
            content: "hi",
            senderId: UUID.fromBackendId(backendUserId),
            senderDisplayName: nil,
            receiverId: nil,
            conversationBackendId: 1,
            channelBackendId: nil,
            messageType: .direct,
            isRead: false,
            attachments: nil,
            createdAt: Date()
        )

        #expect(sentMessage.senderId == currentUser.id)
    }

    @Test func postMapsAuthorPrincipalId() async throws {
        let now = Date()
        let dto = PostDTO(
            id: 1,
            fypRank: nil,
            fypSourcePool: nil,
            authorId: nil,
            authorHandle: nil,
            authorDisplayName: nil,
            authorFirstName: nil,
            authorLastName: nil,
            authorProfileImageUrl: nil,
            authorIsAnonymous: true,
            authorPrincipalId: 456,
            anonProfileId: 123,
            companyId: nil,
            communityId: 99,
            communityName: nil,
            communityShortName: nil,
            communityKind: nil,
            content: "Hello",
            mediaAssetId: nil,
            mediaAssetIds: nil,
            mediaAssetIdsSnake: nil,
            mediaUrl: nil,
            cdnUrl: nil,
            likesCount: nil,
            userLiked: nil,
            commentsCount: nil,
            shareCount: nil,
            repostCount: nil,
            viewerHasReposted: nil,
            repostedByFollowedUsers: nil,
            repostedByFollowedUsersCount: nil,
            createdAt: now,
            isSaved: nil,
            isAnonymous: true,
            authorDisplayCommunity: nil,
            authorDisplaySpecialization: nil,
            poll: nil,
            isUnderReview: nil,
            viewerCapabilities: nil
        )

        let post = Post(dto: dto)
        #expect(post.authorPrincipalId == 456)
        #expect(post.anonProfileId == 123)
        #expect(post.isAnonymous == true)
    }

    @Test func blockedUserMapsPrincipalId() async throws {
        let dto = BlockedUserDTO(
            principalId: 77,
            id: 42,
            kind: "user",
            handle: "someone",
            displayName: "Someone",
            profileImageUrl: nil,
            companyId: 1,
            isAnonymous: false
        )

        let user = BlockedUser(dto: dto)
        #expect(user.backendId == 42)
        #expect(user.principalId == 77)
    }

    @Test func userMapsViewerBlockFlagsFromProfileResponse() async throws {
        let payload = """
        {
          "id": 42,
          "handle": "someone",
          "company_id": 1,
          "viewer_has_blocked": true,
          "viewer_blocked_by": false
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dto = try decoder.decode(UserDTO.self, from: Data(payload.utf8))
        let user = User(dto: dto, profile: nil)

        #expect(user.viewerHasBlocked == true)
        #expect(user.viewerBlockedBy == false)
    }

    @Test func blockPrincipalUsesAuthorizationInJwtMode() async throws {
        let requestBox = RequestBox()
        RequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"principal_id":456,"blocked":true}"#.utf8)
            return (response, data)
        }
        defer { RequestCaptureURLProtocol.requestHandler = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RequestCaptureURLProtocol.self]
        let session = URLSession(configuration: config)
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: StaticTokenProvider(token: "jwt-token")
        )
        let service = BlockService(apiClient: apiClient, anonService: AnonService(apiClient: apiClient))

        _ = try await service.blockPrincipal(principalId: 456, asAnonymousActor: false, communityId: nil)

        guard let request = requestBox.request else {
            Issue.record("Expected captured request for blockPrincipal")
            return
        }
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v1/principals/456/block")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
        #expect(request.value(forHTTPHeaderField: "X-Actor") == nil)
    }

    @Test func unblockPrincipalUsesAuthorizationInJwtMode() async throws {
        let requestBox = RequestBox()
        RequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"principal_id":456,"blocked":false}"#.utf8)
            return (response, data)
        }
        defer { RequestCaptureURLProtocol.requestHandler = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RequestCaptureURLProtocol.self]
        let session = URLSession(configuration: config)
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: StaticTokenProvider(token: "jwt-token")
        )
        let service = BlockService(apiClient: apiClient, anonService: AnonService(apiClient: apiClient))

        _ = try await service.unblockPrincipal(principalId: 456, asAnonymousActor: false, communityId: nil)

        guard let request = requestBox.request else {
            Issue.record("Expected captured request for unblockPrincipal")
            return
        }
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path == "/v1/principals/456/block")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
        #expect(request.httpBody == nil)
    }

    @Test func apiClientBlocksRealNetworkByDefaultInUnitTests() async throws {
        setenv("LOOPED_BLOCK_NETWORK_IN_TESTS", "1", 1)
        defer { unsetenv("LOOPED_BLOCK_NETWORK_IN_TESTS") }

        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: .shared,
            tokenStorage: TokenStorage(),
            tokenProvider: nil
        )

        do {
            let _: EmptyResponse = try await apiClient.get("/", requiresAuth: false)
            Issue.record("Expected network guard to block unit-test outbound call")
        } catch {
            guard let apiError = error as? APIError else {
                Issue.record("Expected APIError.networkError, got: \(error)")
                return
            }
            guard case .networkError = apiError else {
                Issue.record("Expected APIError.networkError, got: \(apiError)")
                return
            }
            #expect(error.localizedDescription.contains("Blocked outbound network call in unit tests"))
        }
    }

}
