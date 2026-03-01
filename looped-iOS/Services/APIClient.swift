import Foundation

class APIClient {
    private static let dateFormatterLock = NSLock()
    private static let iso8601FormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let retryAfterDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter
    }()

    private let baseURL: URL
    private let session: URLSession
    private let tokenStorage: TokenStorage
    private let tokenProvider: AuthTokenProvider?
    private static let blockNetworkInTestsEnvKey = "LOOPED_BLOCK_NETWORK_IN_TESTS"
    private static let allowNetworkInTestsEnvKey = "LOOPED_ALLOW_NETWORK_IN_TESTS"
    
    init(
        baseURL: String? = nil,
        session: URLSession = .shared,
        tokenStorage: TokenStorage = TokenStorage(),
        tokenProvider: AuthTokenProvider? = FirebaseAuthTokenProvider()
    ) {
        self.baseURL = LoopedEnvironment.apiBaseURL(override: baseURL)
        self.session = session
        self.tokenStorage = tokenStorage
        self.tokenProvider = tokenProvider
    }
    
    func get<T: Decodable>(
        _ endpoint: String,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }
        
        return try await performRequest(request)
    }

    func getData(
        _ endpoint: String,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }

        return try await performRequestData(request)
    }
    
    func post<T: Encodable, U: Decodable>(
        _ endpoint: String,
        body: T,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> U {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await performRequest(request)
    }

    func postData<T: Encodable>(
        _ endpoint: String,
        body: T,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }

        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequestData(request)
    }
    
    /// POST with extra headers (e.g., Idempotency-Key)
    func postWithHeaders<T: Encodable, U: Decodable>(
        _ endpoint: String,
        body: T,
        headers: [String: String],
        requiresAuth: Bool = true
    ) async throws -> U {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in request.setValue(value, forHTTPHeaderField: key) }
        if requiresAuth {
            await addAuthHeader(&request)
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await performRequest(request)
    }

    func postDataWithHeaders<T: Encodable>(
        _ endpoint: String,
        body: T,
        headers: [String: String],
        requiresAuth: Bool = true
    ) async throws -> Data {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in request.setValue(value, forHTTPHeaderField: key) }
        if requiresAuth {
            await addAuthHeader(&request)
        }

        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequestData(request)
    }
    
    func put<T: Encodable, U: Decodable>(
        _ endpoint: String,
        body: T,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> U {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await performRequest(request)
    }

    func put<T: Decodable>(
        _ endpoint: String,
        expecting: T.Type,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }

        return try await performRequest(request)
    }

    func putData<T: Encodable>(
        _ endpoint: String,
        body: T,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }

        request.httpBody = try JSONEncoder().encode(body)

        return try await performRequestData(request)
    }

    func patch<T: Encodable, U: Decodable>(
        _ endpoint: String,
        body: T,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> U {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }

        request.httpBody = try JSONEncoder().encode(body)

        return try await performRequest(request)
    }

    func patchData<T: Encodable>(
        _ endpoint: String,
        body: T,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }

        request.httpBody = try JSONEncoder().encode(body)

        return try await performRequestData(request)
    }
    
    func delete(
        _ endpoint: String,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws {
        let _: EmptyResponse = try await delete(
            endpoint,
            expecting: EmptyResponse.self,
            requiresAuth: requiresAuth,
            headers: headers
        )
    }

    func delete<T: Decodable>(
        _ endpoint: String,
        expecting: T.Type,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> T {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }
        
        return try await performRequest(request)
    }

    func delete<T: Encodable, U: Decodable>(
        _ endpoint: String,
        body: T,
        requiresAuth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> U {
        let url = makeURL(for: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if requiresAuth {
            await addAuthHeader(&request)
        }

        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request)
    }
    
    private func addAuthHeader(_ request: inout URLRequest) async {
        // Prefer FirebaseAuth ID token when available
        if let provider = tokenProvider {
            do {
                if let token = try await provider.currentIDToken() {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    return
                }
            } catch {
                // ignore and fall back
            }
        }
        // Fallback to any token stored locally (legacy flow)
        if let token = tokenStorage.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func makeURL(for endpoint: String) -> URL {
        if let absolute = URL(string: endpoint), absolute.scheme != nil {
            return absolute
        }
        if let relative = URL(string: endpoint, relativeTo: baseURL) {
            return relative
        }
        return baseURL.appendingPathComponent(endpoint)
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            try enforceNoRealNetworkInUnitTests(for: request)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            logAnonEnrollmentRequestIdIfNeeded(request: request, response: httpResponse)

            guard 200...299 ~= httpResponse.statusCode else {
                #if DEBUG
                if shouldLogErrorResponse(request: request) {
                    logErrorResponse(request: request, data: data, statusCode: httpResponse.statusCode)
                }
                #endif
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }

                // /v1/me may return 409 with a full identity payload for onboarding-incomplete users.
                if httpResponse.statusCode == 409,
                   request.url?.path == "/v1/me",
                   T.self == IdentityResponseDTO.self {
                    do {
                        let decodedIdentity = try await decodeOnBackground(IdentityResponseDTO.self, from: data) { decoder in
                            decoder.dateDecodingStrategy = .custom { decoder in
                                let container = try decoder.singleValueContainer()
                                let value = try container.decode(String.self)
                                APIClient.dateFormatterLock.lock()
                                defer { APIClient.dateFormatterLock.unlock() }
                                if let date = APIClient.iso8601FormatterWithFractional.date(from: value)
                                    ?? APIClient.iso8601Formatter.date(from: value) {
                                    return date
                                }
                                throw DecodingError.dataCorruptedError(
                                    in: container,
                                    debugDescription: "Invalid ISO-8601 date: \(value)"
                                )
                            }
                            decoder.keyDecodingStrategy = .convertFromSnakeCase
                        }
                        // swiftlint:disable:next force_cast
                        return decodedIdentity as! T
                    } catch {
                        // Fall back to structured error parsing below.
                    }
                }
                // Try to parse structured error
                if let errorPayload = try? await decodeOnBackground(ServerError.self, from: data, configure: { _ in }) {
                    publishAuthGatingIfNeeded(statusCode: httpResponse.statusCode, payload: errorPayload)
                    let retryAfterSeconds = resolveRetryAfterSeconds(
                        from: httpResponse,
                        payloadRetryAfterSeconds: errorPayload.retryAfterSeconds
                    )
                    if httpResponse.statusCode == 429 {
                        throw APIError.rateLimited(
                            code: httpResponse.statusCode,
                            error: errorPayload.resolvedErrorCode,
                            message: errorPayload.message,
                            retryAfterSeconds: retryAfterSeconds
                        )
                    }
                    throw APIError.apiError(
                        code: httpResponse.statusCode,
                        error: errorPayload.resolvedErrorCode,
                        message: errorPayload.message
                    )
                }
                if httpResponse.statusCode == 429 {
                    throw APIError.rateLimited(
                        code: httpResponse.statusCode,
                        error: "rate_limited",
                        message: nil,
                        retryAfterSeconds: resolveRetryAfterSeconds(from: httpResponse, payloadRetryAfterSeconds: nil)
                    )
                }
                throw APIError.serverError(httpResponse.statusCode)
            }

            #if DEBUG
            if shouldLogProfileResponse(request: request) {
                let method = request.httpMethod ?? "GET"
                let path = request.url?.path ?? "unknown"
                let snippet = String(decoding: data, as: UTF8.self)
                let body = snippet.count > 4000 ? String(snippet.prefix(4000)) + "..." : snippet
                print("Profile response: \(method) \(path) status=\(httpResponse.statusCode)")
                print("Profile response body: \(body)")
            }
            #endif

            // Handle empty bodies (e.g., 204) for types expecting EmptyResponse
            if data.isEmpty, T.self == EmptyResponse.self {
                // swiftlint:disable:next force_cast
                return EmptyResponse() as! T
            }

            do {
                return try await decodeOnBackground(T.self, from: data) { decoder in
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let value = try container.decode(String.self)
                        APIClient.dateFormatterLock.lock()
                        defer { APIClient.dateFormatterLock.unlock() }
                        if let date = APIClient.iso8601FormatterWithFractional.date(from: value)
                            ?? APIClient.iso8601Formatter.date(from: value) {
                            return date
                        }
                        throw DecodingError.dataCorruptedError(
                            in: container,
                            debugDescription: "Invalid ISO-8601 date: \(value)"
                        )
                    }
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                }
            } catch let decodingError as DecodingError {
                #if DEBUG
                let method = request.httpMethod ?? "GET"
                let path = request.url?.absoluteString ?? "unknown"
                let snippet = String(decoding: data, as: UTF8.self)
                let body = snippet.count > 4000 ? String(snippet.prefix(4000)) + "..." : snippet
                print("Decoding error: \(method) \(path)")
                print("Decoding error details: \(decodingError)")
                print("Decoding error body: \(body)")
                #endif
                throw APIError.decodingError(decodingError)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func performRequestData(_ request: URLRequest) async throws -> Data {
        do {
            try enforceNoRealNetworkInUnitTests(for: request)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            logAnonEnrollmentRequestIdIfNeeded(request: request, response: httpResponse)

            guard 200...299 ~= httpResponse.statusCode else {
                #if DEBUG
                if shouldLogErrorResponse(request: request) {
                    logErrorResponse(request: request, data: data, statusCode: httpResponse.statusCode)
                }
                #endif
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                if let errorPayload = try? await decodeOnBackground(ServerError.self, from: data, configure: { _ in }) {
                    publishAuthGatingIfNeeded(statusCode: httpResponse.statusCode, payload: errorPayload)
                    let retryAfterSeconds = resolveRetryAfterSeconds(
                        from: httpResponse,
                        payloadRetryAfterSeconds: errorPayload.retryAfterSeconds
                    )
                    if httpResponse.statusCode == 429 {
                        throw APIError.rateLimited(
                            code: httpResponse.statusCode,
                            error: errorPayload.resolvedErrorCode,
                            message: errorPayload.message,
                            retryAfterSeconds: retryAfterSeconds
                        )
                    }
                    throw APIError.apiError(
                        code: httpResponse.statusCode,
                        error: errorPayload.resolvedErrorCode,
                        message: errorPayload.message
                    )
                }
                if httpResponse.statusCode == 429 {
                    throw APIError.rateLimited(
                        code: httpResponse.statusCode,
                        error: "rate_limited",
                        message: nil,
                        retryAfterSeconds: resolveRetryAfterSeconds(from: httpResponse, payloadRetryAfterSeconds: nil)
                    )
                }
                throw APIError.serverError(httpResponse.statusCode)
            }

            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func shouldCaptureAnonEnrollmentRequestId(request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return false }
        return path.hasSuffix("/anon/issuer")
            || path.hasSuffix("/anon/issue")
            || path.hasSuffix("/anon/register")
            || path.hasSuffix("/v1/devices/app-attest/challenge")
            || path.hasSuffix("/v1/devices/app-attest/complete")
            || path.hasSuffix("/v1/devices/app-attest/status")
    }

    private func logAnonEnrollmentRequestIdIfNeeded(request: URLRequest, response: HTTPURLResponse) {
        guard shouldCaptureAnonEnrollmentRequestId(request: request) else { return }
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "unknown"
        let requestId = response.value(forHTTPHeaderField: "X-Request-Id") ?? "<missing>"
        print("Anon enrollment request-id: \(method) \(path) status=\(response.statusCode) requestId=\(requestId)")
    }

    private func shouldLogProfileResponse(request: URLRequest) -> Bool {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["LOOPED_LOG_PROFILE_RESPONSES"] == "1" else { return false }

        guard request.httpMethod == "GET", let path = request.url?.path else { return false }
        if path.hasPrefix("/v1/users/") || path.hasPrefix("/v1/anon/") { return true }
        // Helps debug profile repost tabs (e.g., 200 with empty items after refresh).
        if path == "/v1/posts/reposted" { return true }
        if path.contains("/reposts") { return true }
        // Helps debug missing chats in inbox.
        if path.hasPrefix("/v1/conversations") { return true }
        if path.hasPrefix("/v1/message-requests") { return true }
        if path.hasPrefix("/v1/channels") { return true }
        // Helps debug recommendation cards using handle instead of real names.
        if path.hasPrefix("/v1/recommendations/people") { return true }
        return false
        #else
        return false
        #endif
    }

    #if DEBUG
    private func shouldLogErrorResponse(request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return false }
        if path.hasPrefix("/v1/appeals") || path.hasPrefix("/v1/violations") { return true }

        // Useful for debugging profile + repost-related failures (common "Internal service error" surface).
        if path.hasPrefix("/v1/users/") || path.hasPrefix("/v1/anon/") { return true }
        if path == "/v1/posts/reposted" { return true }
        if path.contains("/reposts") { return true }
        // Useful for debugging messages inbox/listing failures.
        if path.hasPrefix("/v1/conversations") { return true }
        if path.hasPrefix("/v1/message-requests") { return true }
        if path.hasPrefix("/v1/channels") { return true }
        // Useful for debugging recommendation endpoint failures.
        if path.hasPrefix("/v1/recommendations/people") { return true }
        // Useful for debugging message attachments failures.
        if path.hasPrefix("/v1/message-media") { return true }

        return false
    }

    private func logErrorResponse(request: URLRequest, data: Data, statusCode: Int) {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        let snippet = String(decoding: data, as: UTF8.self)
        let body = snippet.isEmpty ? "<empty>" : (snippet.count > 4000 ? String(snippet.prefix(4000)) + "..." : snippet)
        print("API error response: \(method) \(url) status=\(statusCode)")
        print("API error body: \(body)")
    }
    #endif

    private func publishAuthGatingIfNeeded(statusCode: Int, payload: ServerError) {
        guard let context = AuthGatingContext(statusCode: statusCode, payload: payload) else { return }
        NotificationCenter.default.post(name: .authGatingRequired, object: context)
    }

    private func enforceNoRealNetworkInUnitTests(for request: URLRequest) throws {
        let allowNetwork = Self.envFlag(Self.allowNetworkInTestsEnvKey)
        guard !allowNetwork else { return }
        let forceBlock = Self.envFlag(Self.blockNetworkInTestsEnvKey)
        guard forceBlock || Self.isRunningUnitTests() else { return }

        // Allow sessions that explicitly inject a URLProtocol-based transport (test doubles).
        let hasExplicitProtocolMock = session !== URLSession.shared
            && !(session.configuration.protocolClasses ?? []).isEmpty
        guard !hasExplicitProtocolMock else { return }

        throw APIError.networkError(UnitTestNetworkBlockedError(url: request.url))
    }

    private static func isRunningUnitTests() -> Bool {
        if let bundlePath = envValue("XCTestBundlePath")?.lowercased(),
           bundlePath.contains("looped-iostests.xctest") || bundlePath.contains("looped_iostests.xctest") {
            return true
        }
        if let configPath = envValue("XCTestConfigurationFilePath")?.lowercased(),
           configPath.contains("looped-iostests") || configPath.contains("looped_iostests") {
            return true
        }

        let xctestBundles = Bundle.allBundles
            .map(\.bundlePath)
            .map { $0.lowercased() }
            .filter { $0.hasSuffix(".xctest") }

        return xctestBundles.contains {
            $0.contains("looped-iostests.xctest") || $0.contains("looped_iostests.xctest")
        }
    }

    private static func envFlag(_ key: String) -> Bool {
        envValue(key) == "1"
    }

    private static func envValue(_ key: String) -> String? {
        guard let value = getenv(key) else { return nil }
        return String(cString: value)
    }

    private func resolveRetryAfterSeconds(
        from response: HTTPURLResponse,
        payloadRetryAfterSeconds: Int?
    ) -> Int? {
        if let payloadRetryAfterSeconds, payloadRetryAfterSeconds > 0 {
            return payloadRetryAfterSeconds
        }
        guard let rawHeader = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawHeader.isEmpty else {
            return nil
        }

        if let seconds = Int(rawHeader), seconds > 0 {
            return seconds
        }

        if let retryDate = APIClient.retryAfterDateFormatter.date(from: rawHeader) {
            let remaining = Int(ceil(retryDate.timeIntervalSinceNow))
            return remaining > 0 ? remaining : nil
        }

        return nil
    }
}

extension APIClient {
    private func decodeOnBackground<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        configure: @escaping (JSONDecoder) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let decoder = JSONDecoder()
                configure(decoder)
                do {
                    continuation.resume(returning: try decoder.decode(T.self, from: data))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct EmptyResponse: Codable {}

fileprivate struct ServerError: Decodable {
    let error: String
    let errorCode: String?
    let message: String?
    let onboardingStep: RemoteOnboardingStep?
    let currentStep: RemoteOnboardingStep?
    let allowedNextSteps: [RemoteOnboardingStep]?
    let currentStageV2: String?
    let allowedNextStagesV2: [String]?
    let retryAfterSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case error
        case errorCode = "error_code"
        case errorCodeCamel = "errorCode"
        case message
        case onboardingStep = "onboarding_step"
        case onboardingStepCamel = "onboardingStep"
        case currentStep = "current_step"
        case currentStepCamel = "currentStep"
        case allowedNextSteps = "allowed_next_steps"
        case allowedNextStepsCamel = "allowedNextSteps"
        case currentStageV2 = "current_stage_v2"
        case currentStageV2Camel = "currentStageV2"
        case allowedNextStagesV2 = "allowed_next_stages_v2"
        case allowedNextStagesV2Camel = "allowedNextStagesV2"
        case retryAfterSeconds = "retry_after_seconds"
        case retryAfterSecondsCamel = "retryAfterSeconds"
    }

    init(
        error: String,
        errorCode: String? = nil,
        message: String?,
        onboardingStep: RemoteOnboardingStep?,
        currentStep: RemoteOnboardingStep? = nil,
        allowedNextSteps: [RemoteOnboardingStep]? = nil,
        currentStageV2: String? = nil,
        allowedNextStagesV2: [String]? = nil,
        retryAfterSeconds: Int? = nil
    ) {
        self.error = error
        self.errorCode = errorCode
        self.message = message
        self.onboardingStep = onboardingStep
        self.currentStep = currentStep
        self.allowedNextSteps = allowedNextSteps
        self.currentStageV2 = currentStageV2
        self.allowedNextStagesV2 = allowedNextStagesV2
        self.retryAfterSeconds = retryAfterSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedError = try container.decodeIfPresent(String.self, forKey: .error)
        let decodedErrorCode =
            (try? container.decodeIfPresent(String.self, forKey: .errorCode))
            ?? (try? container.decodeIfPresent(String.self, forKey: .errorCodeCamel))
        error = decodedError ?? decodedErrorCode ?? "unknown_error"
        errorCode = decodedErrorCode
        message = try container.decodeIfPresent(String.self, forKey: .message)
        onboardingStep = try ServerError.decodeStep(from: container, snakeKey: .onboardingStep, camelKey: .onboardingStepCamel)
        currentStep = try ServerError.decodeStep(from: container, snakeKey: .currentStep, camelKey: .currentStepCamel)
        allowedNextSteps = try ServerError.decodeSteps(
            from: container,
            snakeKey: .allowedNextSteps,
            camelKey: .allowedNextStepsCamel
        )
        currentStageV2 =
            (try? container.decodeIfPresent(String.self, forKey: .currentStageV2))
            ?? (try? container.decodeIfPresent(String.self, forKey: .currentStageV2Camel))
        allowedNextStagesV2 =
            (try? container.decodeIfPresent([String].self, forKey: .allowedNextStagesV2))
            ?? (try? container.decodeIfPresent([String].self, forKey: .allowedNextStagesV2Camel))
        retryAfterSeconds = try ServerError.decodeRetryAfterSeconds(
            from: container,
            snakeKey: .retryAfterSeconds,
            camelKey: .retryAfterSecondsCamel
        )
    }

    var resolvedErrorCode: String {
        let trimmed = (errorCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return error
    }

    private static func decodeStep(
        from container: KeyedDecodingContainer<CodingKeys>,
        snakeKey: CodingKeys,
        camelKey: CodingKeys
    ) throws -> RemoteOnboardingStep? {
        if let snakeValue = try container.decodeIfPresent(String.self, forKey: snakeKey) {
            return RemoteOnboardingStep(rawValue: snakeValue)
        }
        if let camelValue = try container.decodeIfPresent(String.self, forKey: camelKey) {
            return RemoteOnboardingStep(rawValue: camelValue)
        }
        return nil
    }

    private static func decodeSteps(
        from container: KeyedDecodingContainer<CodingKeys>,
        snakeKey: CodingKeys,
        camelKey: CodingKeys
    ) throws -> [RemoteOnboardingStep]? {
        if let snakeValues = try container.decodeIfPresent([String].self, forKey: snakeKey) {
            return snakeValues.compactMap(RemoteOnboardingStep.init(rawValue:))
        }
        if let camelValues = try container.decodeIfPresent([String].self, forKey: camelKey) {
            return camelValues.compactMap(RemoteOnboardingStep.init(rawValue:))
        }
        return nil
    }

    private static func decodeRetryAfterSeconds(
        from container: KeyedDecodingContainer<CodingKeys>,
        snakeKey: CodingKeys,
        camelKey: CodingKeys
    ) throws -> Int? {
        if let value = try? container.decode(Int.self, forKey: snakeKey) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: camelKey) {
            return value
        }
        if let stringValue = try? container.decode(String.self, forKey: snakeKey),
           let value = Int(stringValue) {
            return value
        }
        if let stringValue = try? container.decode(String.self, forKey: camelKey),
           let value = Int(stringValue) {
            return value
        }
        return nil
    }
}

enum AuthGatingErrorCode: String, Codable {
    case userNotProvisioned = "user_not_provisioned"
    case onboardingIncomplete = "onboarding_incomplete"
    case invalidOnboardingStep = "invalid_onboarding_step"
    case invalidOnboardingStage = "invalid_onboarding_stage"
    case accountDeleted = "account_deleted"
}

struct AuthGatingContext: Equatable {
    let code: AuthGatingErrorCode
    let onboardingStep: RemoteOnboardingStep?
    let currentStep: RemoteOnboardingStep?
    let allowedNextSteps: [RemoteOnboardingStep]?
    let currentStageV2: String?
    let allowedNextStagesV2: [String]?
    let message: String?

    fileprivate init?(statusCode: Int, payload: ServerError) {
        guard let code = AuthGatingErrorCode(rawValue: payload.error) else { return nil }
        switch code {
        case .userNotProvisioned, .onboardingIncomplete, .accountDeleted:
            guard statusCode == 409 else { return nil }
        case .invalidOnboardingStep, .invalidOnboardingStage:
            guard statusCode == 422 else { return nil }
        }
        self.code = code
        self.onboardingStep = payload.onboardingStep
        self.currentStep = payload.currentStep
        self.allowedNextSteps = payload.allowedNextSteps
        self.currentStageV2 = payload.currentStageV2
        self.allowedNextStagesV2 = payload.allowedNextStagesV2
        self.message = payload.message
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case apiError(code: Int, error: String, message: String?)
    case rateLimited(code: Int, error: String, message: String?, retryAfterSeconds: Int?)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response received"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let code):
            return "Server error: \(code)"
        case .apiError(_, let error, let message):
            return message ?? error
        case .rateLimited(_, let error, let message, _):
            return message ?? error
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

private struct UnitTestNetworkBlockedError: LocalizedError {
    let url: URL?

    var errorDescription: String? {
        let target = url?.absoluteString ?? "<unknown>"
        return "Blocked outbound network call in unit tests: \(target)"
    }
}

extension APIError {
    var authGatingContext: AuthGatingContext? {
        switch self {
        case .apiError(let code, let error, let message):
            let payload = ServerError(error: error, message: message, onboardingStep: nil)
            return AuthGatingContext(statusCode: code, payload: payload)
        case .rateLimited:
            return nil
        default:
            return nil
        }
    }

    var isAuthGatingError: Bool {
        authGatingContext != nil
    }

    var apiErrorCode: String? {
        switch self {
        case .apiError(_, let error, _):
            return error
        case .rateLimited(_, let error, _, _):
            return error
        default:
            return nil
        }
    }

    var retryAfterSeconds: Int? {
        switch self {
        case .rateLimited(_, _, _, let retryAfterSeconds):
            return retryAfterSeconds
        default:
            return nil
        }
    }
}
