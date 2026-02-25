import Foundation
import Testing
@testable import looped_iOS

private final class UserIdentityRequestCaptureURLProtocol: URLProtocol {
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

private final class UserIdentityRequestBox {
    var request: URLRequest?
}

private struct UserIdentityStaticTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? {
        token
    }
}

@Suite(.serialized)
struct UserServiceIdentityTests {
    @Test
    func getIdentity_onboardingIncomplete409WithIdentityPayload_decodesResponse() async throws {
        let requestBox = UserIdentityRequestBox()
        UserIdentityRequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            return makeIdentity409Response(for: request)
        }
        defer { UserIdentityRequestCaptureURLProtocol.requestHandler = nil }

        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: makeIdentitySession(),
            tokenStorage: TokenStorage(),
            tokenProvider: UserIdentityStaticTokenProvider(token: "jwt-token")
        )
        let service = UserService(apiClient: apiClient)

        let identity = try await service.getIdentity()

        #expect(requestBox.request?.httpMethod == "GET")
        #expect(requestBox.request?.url?.path == "/v1/me")
        #expect(requestBox.request?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")

        #expect(identity.provisioned == true)
        #expect(identity.onboardingComplete == false)
        #expect(identity.onboardingStep == .verification)
        #expect(identity.user?.id == 45)
        #expect(identity.profileCompletion?.shouldPrompt == true)
        #expect(identity.profileCompletion?.missingPhoto == true)
        #expect(identity.profileCompletion?.missingBio == true)
        #expect(identity.profileCompletion?.missingSpecialization == false)
    }

    @Test
    func dismissProfileCompletionPrompt_decodesProfileCompletionResponse() async throws {
        let requestBox = UserIdentityRequestBox()
        UserIdentityRequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            return makeDismissProfileCompletionResponse(for: request)
        }
        defer { UserIdentityRequestCaptureURLProtocol.requestHandler = nil }

        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: makeIdentitySession(),
            tokenStorage: TokenStorage(),
            tokenProvider: UserIdentityStaticTokenProvider(token: "jwt-token")
        )
        let service = UserService(apiClient: apiClient)

        let response = try await service.dismissProfileCompletionPrompt()

        #expect(requestBox.request?.httpMethod == "POST")
        #expect(requestBox.request?.url?.path == "/v1/me/profile-completion/dismiss")
        #expect(requestBox.request?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
        #expect(response?.shouldPrompt == false)
        #expect(response?.missingPhoto == false)
        #expect(response?.missingBio == true)
        #expect(response?.missingSpecialization == false)
        #expect(response?.dismissedAt != nil)
    }
}

private func makeIdentitySession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [UserIdentityRequestCaptureURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeIdentity409Response(for request: URLRequest) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 409,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    let data = Data(
        """
        {
          "error": "onboarding_incomplete",
          "sub": "firebase-uid-45",
          "iss": "https://securetoken.google.com/example",
          "aud": ["example"],
          "email": "person@example.com",
          "provisioned": true,
          "onboarding_complete": false,
          "onboarding_step": "verification",
          "profile_completion": {
            "should_prompt": true,
            "missing_photo": true,
            "missing_bio": true,
            "missing_specialization": false,
            "dismissed_at": null,
            "completed_at": null
          },
          "user": {
            "id": 45,
            "handle": "person45",
            "username": "person45",
            "display_name": "Person 45",
            "company_id": 3,
            "bio": null,
            "verification": {
              "method": "email",
              "verified": false,
              "verified_at": null
            },
            "profile": null,
            "stats": null,
            "display_community": null,
            "display_specialization": null,
            "profile_image_url": null,
            "show_follower_count": true,
            "hide_anonymous_posts": false,
            "message_permission": "all",
            "created_at": "2026-02-01T00:00:00Z",
            "updated_at": "2026-02-01T00:00:00Z"
          }
        }
        """.utf8
    )
    return (response, data)
}

private func makeDismissProfileCompletionResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    let data = Data(
        """
        {
          "profile_completion": {
            "should_prompt": false,
            "missing_photo": false,
            "missing_bio": true,
            "missing_specialization": false,
            "dismissed_at": "2026-02-25T18:00:00Z",
            "completed_at": null
          }
        }
        """.utf8
    )
    return (response, data)
}
