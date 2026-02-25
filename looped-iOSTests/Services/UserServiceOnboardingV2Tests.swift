import Foundation
import Testing
@testable import looped_iOS

private final class UserOnboardingV2RequestCaptureURLProtocol: URLProtocol {
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

private final class UserOnboardingV2RequestBox {
    var requests: [URLRequest] = []
}

private struct UserOnboardingV2StaticTokenProvider: AuthTokenProvider {
    let token: String

    func currentIDToken() async throws -> String? {
        token
    }
}

@Suite(.serialized)
struct UserServiceOnboardingV2Tests {
    @Test
    func setOnboardingV2VerificationChoice_usesSnakeCasePayload() async throws {
        let requestBox = UserOnboardingV2RequestBox()
        UserOnboardingV2RequestCaptureURLProtocol.requestHandler = { request in
            requestBox.requests.append(request)
            return makeSuccessResponse(for: request)
        }
        defer { UserOnboardingV2RequestCaptureURLProtocol.requestHandler = nil }

        let service = makeService()
        let response = try await service.setOnboardingV2VerificationChoice(path: "photo_id")

        #expect(requestBox.requests.count == 1)
        let request = try #require(requestBox.requests.first)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/v1/users/me/onboarding-v2/verification-choice")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")

        let bodyData = try #require(requestBodyData(from: request))
        let json = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(json["verification_path"] as? String == "photo_id")
        #expect(json["verificationPath"] == nil)

        #expect(response.onboardingComplete == false)
        #expect(response.onboardingStageV2 == "photo_id_verification")
        #expect(response.onboardingContext?.verificationPath == "photo_id")
    }

    @Test
    func setOnboardingV2VerificationChoice_retriesCamelCaseWhenSnakeCaseFails() async throws {
        let requestBox = UserOnboardingV2RequestBox()
        UserOnboardingV2RequestCaptureURLProtocol.requestHandler = { request in
            requestBox.requests.append(request)
            if requestBox.requests.count == 1 {
                return makeFailureResponse(
                    for: request,
                    statusCode: 400,
                    errorCode: "invalid_request",
                    message: "verification_path missing"
                )
            }
            return makeSuccessResponse(for: request)
        }
        defer { UserOnboardingV2RequestCaptureURLProtocol.requestHandler = nil }

        let service = makeService()
        let response = try await service.setOnboardingV2VerificationChoice(path: "photo_id")

        #expect(requestBox.requests.count == 2)

        let firstRequest = try #require(requestBox.requests.first)
        let firstBodyData = try #require(requestBodyData(from: firstRequest))
        let firstJSON = try #require(try JSONSerialization.jsonObject(with: firstBodyData) as? [String: Any])
        #expect(firstJSON["verification_path"] as? String == "photo_id")
        #expect(firstJSON["verificationPath"] == nil)

        let secondRequest = try #require(requestBox.requests.last)
        let secondBodyData = try #require(requestBodyData(from: secondRequest))
        let secondJSON = try #require(try JSONSerialization.jsonObject(with: secondBodyData) as? [String: Any])
        #expect(secondJSON["verificationPath"] as? String == "photo_id")

        #expect(response.onboardingStageV2 == "photo_id_verification")
    }
}

private func makeOnboardingV2Session() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [UserOnboardingV2RequestCaptureURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeService() -> UserService {
    let apiClient = APIClient(
        baseURL: "https://example.com",
        session: makeOnboardingV2Session(),
        tokenStorage: TokenStorage(),
        tokenProvider: UserOnboardingV2StaticTokenProvider(token: "jwt-token")
    )
    return UserService(apiClient: apiClient)
}

private func makeSuccessResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    let data = Data(
        """
        {
          "onboarding_complete": false,
          "onboarding_stage_v2": "photo_id_verification",
          "onboarding_context": {
            "verification_path": "photo_id"
          }
        }
        """.utf8
    )
    return (response, data)
}

private func makeFailureResponse(
    for request: URLRequest,
    statusCode: Int,
    errorCode: String,
    message: String
) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: request.url!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    let data = Data(
        """
        {
          "error": "\(errorCode)",
          "message": "\(message)"
        }
        """.utf8
    )
    return (response, data)
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
