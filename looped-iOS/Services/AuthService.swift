import Foundation
import Combine

class AuthService: AuthServiceProtocol {
    private let apiClient: APIClient
    private let tokenStorage: TokenStorage
    
    @Published private var _isAuthenticated = false
    
    var authStateChanged: AnyPublisher<Bool, Never> {
        $_isAuthenticated.eraseToAnyPublisher()
    }
    
    var isAuthenticated: Bool {
        _isAuthenticated
    }
    
    init(apiClient: APIClient = APIClient(), tokenStorage: TokenStorage = TokenStorage()) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
        self._isAuthenticated = tokenStorage.hasValidToken()
    }
    
    func login(email: String, password: String) async throws {
        let request = LoginRequest(email: email, password: password)
        let response: LoginResponse = try await apiClient.post("/auth/login", body: request)
        
        tokenStorage.store(token: response.token, refreshToken: response.refreshToken)
        _isAuthenticated = true
    }
    
    func signUp(email: String, password: String, username: String, company: String) async throws {
        let request = RegistrationRequest(
            email: email,
            password: password,
            username: username,
            company: company,
            employmentVerificationData: email
        )
        
        let response: LoginResponse = try await apiClient.post("/auth/register", body: request)
        
        tokenStorage.store(token: response.token, refreshToken: response.refreshToken)
        _isAuthenticated = true
    }
    
    func signOut() {
        tokenStorage.clear()
        _isAuthenticated = false
    }
    
    func refreshToken() async throws {
        guard let refreshToken = tokenStorage.refreshToken else {
            throw AuthError.noRefreshToken
        }
        
        let request = ["refreshToken": refreshToken]
        let response: LoginResponse = try await apiClient.post("/auth/refresh", body: request)
        
        tokenStorage.store(token: response.token, refreshToken: response.refreshToken)
    }
}

enum AuthError: Error, LocalizedError {
    case noRefreshToken
    case invalidCredentials
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error occurred"
        }
    }
}