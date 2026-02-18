import Foundation
import CryptoKit
import Testing
@testable import looped_iOS

private final class PollsRequestCaptureURLProtocol: URLProtocol {
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

private final class PollsRequestBox {
    var request: URLRequest?
}

private final class PollsRequestSequenceBox {
    var requests: [URLRequest] = []
    var voteRequestCount = 0
}

private final class PollsCounterBox {
    var value = 0
}

private struct PollsStaticTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? {
        token
    }
}

@Suite(.serialized)
struct PollsServiceTests {
    @Test
    func vote_usesJwtAuthInRegularMode() async throws {
        let requestBox = PollsRequestBox()
        PollsRequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            return makeSuccessResponse(for: request, selectedOptionId: 3)
        }
        defer { PollsRequestCaptureURLProtocol.requestHandler = nil }

        let session = makeSession()
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: PollsStaticTokenProvider(token: "jwt-token")
        )
        let anonService = AnonService(apiClient: apiClient, store: AnonIdentityStore())
        let service = PollsService(
            apiClient: apiClient,
            anonService: anonService,
            isAnonymousModeEnabled: { false }
        )

        _ = try await service.vote(pollId: 55, selectedOptionIds: [3], communityId: 77)

        guard let request = requestBox.request else {
            Issue.record("Expected captured request for poll vote")
            return
        }
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/v1/polls/55/vote")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
        #expect(request.value(forHTTPHeaderField: "X-Actor") == nil)

        let body = try decodeBody(PollVoteRequestDTO.self, from: request)
        #expect(body.selectedOptionIds == [3])
        #expect(body.asAnon == nil)
        #expect(body.anonProfileId == nil)
        #expect(body.anonCert == nil)
        #expect(body.anonCertKid == nil)
        #expect(body.anonSig == nil)
    }

    @Test
    func vote_usesAnonActorProofInAnonymousMode() async throws {
        let requestBox = PollsRequestBox()
        PollsRequestCaptureURLProtocol.requestHandler = { request in
            requestBox.request = request
            return makeSuccessResponse(for: request, selectedOptionId: 4)
        }
        defer { PollsRequestCaptureURLProtocol.requestHandler = nil }

        let store = AnonIdentityStore()
        let membership = AnonCommunityMembership(
            cert: "cert-77",
            certKid: "kid-77",
            certExpiresAt: Date().addingTimeInterval(3600)
        )
        store.saveIdentity(
            AnonIdentity(
                profileId: 9001,
                handle: "anon9001",
                memberships: [77: membership]
            )
        )
        store.savePrivateKey(Curve25519.Signing.PrivateKey())
        defer {
            store.clearAll()
        }

        let session = makeSession()
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: PollsStaticTokenProvider(token: "jwt-token")
        )
        let anonService = AnonService(apiClient: apiClient, store: store)
        let service = PollsService(
            apiClient: apiClient,
            anonService: anonService,
            isAnonymousModeEnabled: { true }
        )

        _ = try await service.vote(pollId: 55, selectedOptionIds: [4], communityId: 77)

        guard let request = requestBox.request else {
            Issue.record("Expected captured request for anonymous poll vote")
            return
        }
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/v1/polls/55/vote")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "X-Actor") == "anon")

        let body = try decodeBody(PollVoteRequestDTO.self, from: request)
        #expect(body.selectedOptionIds == [4])
        #expect(body.asAnon == true)
        #expect(body.anonProfileId == 9001)
        #expect(body.anonCert == "cert-77")
        #expect(body.anonCertKid == "kid-77")
        #expect((body.anonSig ?? "").isEmpty == false)
    }

    @Test
    func vote_retriesOnceAfterInvalidAnonProofInAnonymousMode() async throws {
        let requestSequence = PollsRequestSequenceBox()
        PollsRequestCaptureURLProtocol.requestHandler = { request in
            requestSequence.requests.append(request)
            guard request.url?.path == "/v1/polls/55/vote" else {
                return makeSuccessResponse(for: request, selectedOptionId: 4)
            }

            requestSequence.voteRequestCount += 1
            if requestSequence.voteRequestCount == 1 {
                return makeErrorResponse(
                    for: request,
                    statusCode: 403,
                    error: "invalid_anon_proof",
                    message: "Proof expired"
                )
            }
            return makeSuccessResponse(for: request, selectedOptionId: 4)
        }
        defer { PollsRequestCaptureURLProtocol.requestHandler = nil }

        let store = AnonIdentityStore()
        let membership = AnonCommunityMembership(
            cert: "cert-77",
            certKid: "kid-77",
            certExpiresAt: Date().addingTimeInterval(3600)
        )
        store.saveIdentity(
            AnonIdentity(
                profileId: 9001,
                handle: "anon9001",
                memberships: [77: membership]
            )
        )
        store.savePrivateKey(Curve25519.Signing.PrivateKey())
        defer {
            store.clearAll()
        }

        let session = makeSession()
        let apiClient = APIClient(
            baseURL: "https://example.com",
            session: session,
            tokenStorage: TokenStorage(),
            tokenProvider: PollsStaticTokenProvider(token: "jwt-token")
        )
        let anonService = AnonService(apiClient: apiClient, store: store)
        let recoveryCalls = PollsCounterBox()
        let service = PollsService(
            apiClient: apiClient,
            anonService: anonService,
            isAnonymousModeEnabled: { true },
            recoverAnonIdentity: { _ in
                recoveryCalls.value += 1
            }
        )

        let updated = try await service.vote(pollId: 55, selectedOptionIds: [4], communityId: 77)

        #expect(requestSequence.voteRequestCount == 2)
        #expect(recoveryCalls.value == 1)
        #expect(updated.viewer?.hasVoted == true)
        #expect(requestSequence.requests.count == 2)
        #expect(requestSequence.requests[0].value(forHTTPHeaderField: "Authorization") == nil)
        #expect(requestSequence.requests[0].value(forHTTPHeaderField: "X-Actor") == "anon")
        #expect(requestSequence.requests[1].value(forHTTPHeaderField: "Authorization") == nil)
        #expect(requestSequence.requests[1].value(forHTTPHeaderField: "X-Actor") == "anon")

        let firstBody = try decodeBody(PollVoteRequestDTO.self, from: requestSequence.requests[0])
        let secondBody = try decodeBody(PollVoteRequestDTO.self, from: requestSequence.requests[1])
        #expect(firstBody.selectedOptionIds == [4])
        #expect(firstBody.asAnon == true)
        #expect(secondBody.selectedOptionIds == [4])
        #expect(secondBody.asAnon == true)
    }
}

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [PollsRequestCaptureURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeSuccessResponse(for request: URLRequest, selectedOptionId: Int) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    let data = Data(
        """
        {
          "id": 55,
          "postId": 10,
          "question": "Where should we go?",
          "maxSelections": 1,
          "status": "OPEN",
          "options": [
            {
              "id": \(selectedOptionId),
              "text": "Option",
              "voteCount": 1,
              "votePercent": 100.0
            }
          ],
          "totalVotes": 1,
          "viewer": {
            "hasVoted": true,
            "selectedOptionIds": [\(selectedOptionId)],
            "canChangeVote": true
          }
        }
        """.utf8
    )
    return (response, data)
}

private func makeErrorResponse(
    for request: URLRequest,
    statusCode: Int,
    error: String,
    message: String
) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    let data = Data(#"{"error":"\#(error)","message":"\#(message)"}"#.utf8)
    return (response, data)
}

private func decodeBody<T: Decodable>(_ type: T.Type, from request: URLRequest) throws -> T {
    guard let data = requestBodyData(from: request) else {
        throw APIError.invalidResponse
    }
    return try JSONDecoder().decode(type, from: data)
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
