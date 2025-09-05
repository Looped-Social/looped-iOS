import Foundation

class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStorage: TokenStorage
    
    init(
        baseURL: String = "https://api.looped.app",
        session: URLSession = .shared,
        tokenStorage: TokenStorage = TokenStorage()
    ) {
        self.baseURL = URL(string: baseURL)!
        self.session = session
        self.tokenStorage = tokenStorage
    }
    
    func get<T: Codable>(_ endpoint: String) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(&request)
        
        return try await performRequest(request)
    }
    
    func post<T: Codable, U: Codable>(_ endpoint: String, body: T) async throws -> U {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(&request)
        
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await performRequest(request)
    }
    
    func put<T: Codable, U: Codable>(_ endpoint: String, body: T) async throws -> U {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(&request)
        
        request.httpBody = try JSONEncoder().encode(body)
        
        return try await performRequest(request)
    }
    
    func delete(_ endpoint: String) async throws {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addAuthHeader(&request)
        
        let _: EmptyResponse = try await performRequest(request)
    }
    
    private func addAuthHeader(_ request: inout URLRequest) {
        if let token = tokenStorage.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func performRequest<T: Codable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

struct EmptyResponse: Codable {}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(Int)
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
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}