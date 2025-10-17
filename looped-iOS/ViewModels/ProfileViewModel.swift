import Foundation
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var userProfile: UserProfile?
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
            let fetchedUser = try await userService.getCurrentUser()
            user = fetchedUser

            if let profile = MockUserProfiles.getUserProfile(byId: fetchedUser.id) {
                userProfile = profile
            }

            userPosts = MockPosts.getPostsByUser(fetchedUser.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateProfile(displayName: String?, bio: String? = nil, isAnonymous: Bool) async {
        do {
            let updatedUser = try await userService.updateProfile(displayName: displayName, bio: bio, isAnonymous: isAnonymous)
            user = updatedUser

            if let existingProfile = userProfile {
                userProfile = UserProfile(
                    id: existingProfile.id,
                    username: existingProfile.username,
                    displayName: displayName ?? existingProfile.displayName,
                    handle: existingProfile.handle,
                    company: existingProfile.company,
                    jobTitle: existingProfile.jobTitle,
                    bio: bio ?? existingProfile.bio,
                    profileImageURL: existingProfile.profileImageURL,
                    isVerified: existingProfile.isVerified,
                    isAnonymous: isAnonymous,
                    yearsInLoop: existingProfile.yearsInLoop,
                    followingCount: existingProfile.followingCount,
                    followersCount: existingProfile.followersCount,
                    postsCount: existingProfile.postsCount,
                    commentsCount: existingProfile.commentsCount,
                    isCurrentUser: existingProfile.isCurrentUser,
                    createdAt: existingProfile.createdAt,
                    updatedAt: Date()
                )
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func signOut() {
        authService.signOut()
    }
}
