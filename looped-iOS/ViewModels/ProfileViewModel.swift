import Foundation
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var userPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userService: UserServiceProtocol
    private let authService: AuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        userService: UserServiceProtocol = MockConfig.useMockData ? MockUserService() : UserService(),
        authService: AuthServiceProtocol = MockConfig.useMockData ? MockAuthService() : AuthService()
    ) {
        self.userService = userService
        self.authService = authService
    }
    
    func loadUserProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            user = try await userService.getCurrentUser()
            // Load user's posts - filter MockPosts by current user
            if let currentUser = user {
                userPosts = MockPosts.getPostsByUser(currentUser.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateProfile(displayName: String?, isAnonymous: Bool) async {
        do {
            user = try await userService.updateProfile(displayName: displayName, isAnonymous: isAnonymous)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signOut() {
        authService.signOut()
    }
}