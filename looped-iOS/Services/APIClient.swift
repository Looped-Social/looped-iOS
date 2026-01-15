import Foundation

class APIClient {
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

    private let baseURL: URL
    private let session: URLSession
    private let tokenStorage: TokenStorage
    private let tokenProvider: AuthTokenProvider?
    
    init(
        baseURL: String? = nil,
        session: URLSession = .shared,
        tokenStorage: TokenStorage = TokenStorage(),
        tokenProvider: AuthTokenProvider? = FirebaseAuthTokenProvider()
    ) {
        let resolvedBaseURL = baseURL ?? Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        self.baseURL = URL(string: resolvedBaseURL ?? "https://api.mylooped.app")!
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
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard 200...299 ~= httpResponse.statusCode else {
                #if DEBUG
                if shouldLogErrorResponse(request: request) {
                    logErrorResponse(request: request, data: data, statusCode: httpResponse.statusCode)
                }
                #endif
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                // Try to parse structured error
                if let errorPayload = try? JSONDecoder().decode(ServerError.self, from: data) {
                    throw APIError.apiError(code: httpResponse.statusCode, error: errorPayload.error, message: errorPayload.message)
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

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
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

            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
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
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard 200...299 ~= httpResponse.statusCode else {
                #if DEBUG
                if shouldLogErrorResponse(request: request) {
                    logErrorResponse(request: request, data: data, statusCode: httpResponse.statusCode)
                }
                #endif
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                if let errorPayload = try? JSONDecoder().decode(ServerError.self, from: data) {
                    throw APIError.apiError(code: httpResponse.statusCode, error: errorPayload.error, message: errorPayload.message)
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

    private func shouldLogProfileResponse(request: URLRequest) -> Bool {
        guard request.httpMethod == "GET", let path = request.url?.path else { return false }
        if path.hasPrefix("/v1/users/") || path.hasPrefix("/v1/anon/") { return true }
        // Helps debug profile repost tabs (e.g., 200 with empty items after refresh).
        if path == "/v1/posts/reposted" { return true }
        if path.contains("/reposts") { return true }
        // Helps debug missing chats in inbox.
        if path.hasPrefix("/v1/conversations") { return true }
        if path.hasPrefix("/v1/message-requests") { return true }
        if path.hasPrefix("/v1/channels") { return true }
        return false
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

}

struct EmptyResponse: Codable {}

private struct ServerError: Codable {
    let error: String
    let message: String?
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case apiError(code: Int, error: String, message: String?)
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
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
