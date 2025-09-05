import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    private let authService: AuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthServiceProtocol = MockConfig.useMockData ? MockAuthService() : AuthService()) {
        self.authService = authService
        
        authService.authStateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
            }
            .store(in: &cancellables)
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, username: String, company: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(
                email: email,
                password: password,
                username: username,
                company: company
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() {
        authService.signOut()
    }
}