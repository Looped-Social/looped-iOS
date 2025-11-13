import Foundation
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var userProfile: UserProfile?
    @Published var userPosts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingPosts = false
    @Published var errorMessage: String?
    
    private let userService: UserServiceProtocol
    private let feedService: FeedServiceProtocol
    private let authService: AuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        userService: UserServiceProtocol = UserService(),
        feedService: FeedServiceProtocol = FeedService(),
        authService: AuthServiceProtocol = AuthService()
    ) {
        self.userService = userService
        self.feedService = feedService
        self.authService = authService
    }
    
    func loadUserProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedUser = try await userService.getCurrentUser()
            user = fetchedUser
            userProfile = UserProfile.from(user: fetchedUser)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
        await loadUserPosts()
    }
    
    func updateProfile(displayName: String?, bio: String? = nil, isAnonymous: Bool) async {
        do {
            let updatedUser = try await userService.updateProfile(displayName: displayName, bio: bio, isAnonymous: isAnonymous)
            user = updatedUser

            userProfile = UserProfile.from(user: updatedUser)

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signOut() {
        authService.signOut()
        user = nil
        userProfile = nil
        userPosts = []
    }

    func loadUserPosts(limit: Int = 20) async {
        guard let user = user, user.backendId > 0 else {
            userPosts = []
            isLoadingPosts = false
            return
        }
        isLoadingPosts = true
        errorMessage = nil
        do {
            let page = try await feedService.fetchUserPosts(userId: user.backendId, limit: limit, cursor: nil)
            userPosts = page.posts
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingPosts = false
    }
}
