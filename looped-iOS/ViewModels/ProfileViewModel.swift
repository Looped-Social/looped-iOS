import Foundation
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var userProfile: UserProfile?
    @Published var anonProfile: AnonProfile?
    @Published var userPosts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingPosts = false
    @Published var isLoadingAnonymous = false
    @Published var errorMessage: String?
    @Published var anonErrorMessage: String?
    
    private let userService: UserServiceProtocol
    private let feedService: FeedServiceProtocol
    private let authService: AuthServiceProtocol
    private let anonService: AnonService
    private let verificationService: CommunityVerificationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        userService: UserServiceProtocol = UserService(),
        feedService: FeedServiceProtocol = FeedService(),
        authService: AuthServiceProtocol = AuthService(),
        anonService: AnonService = .shared,
        verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()
    ) {
        self.userService = userService
        self.feedService = feedService
        self.authService = authService
        self.anonService = anonService
        self.verificationService = verificationService
    }
    
    func loadUserProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedUser = try await userService.getCurrentUser()
            user = fetchedUser
            userProfile = UserProfile.from(user: fetchedUser, isCurrentUser: true)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        await loadUserPosts()
    }

    func loadAnonymousProfile() async {
        guard !isLoadingAnonymous else { return }
        isLoadingAnonymous = true
        anonErrorMessage = nil

        do {
            let identity = try await anonService.ensureIdentity()
            do {
                anonProfile = try await anonService.fetchProfile(id: identity.profileId)
            } catch {
                // Fall back to local identity when the profile endpoint fails.
                anonProfile = fallbackAnonProfile(identity: identity)
            }
        } catch {
            anonErrorMessage = error.localizedDescription
            anonProfile = nil
        }

        isLoadingAnonymous = false
    }

    func handleAnonymousModeChange(isEnabled: Bool) async {
        if isEnabled {
            do {
                let communityId = await AnonCommunityResolver.resolve(
                    preferredCommunityId: user?.displayCommunity?.id,
                    verificationService: verificationService
                )
                guard let communityId else {
                    throw AnonServiceError.missingCommunityContext
                }
                AnonCommunityResolver.cacheSelectedCommunityId(communityId)
                let identity = try await anonService.ensureIdentity(communityId: communityId)
                do {
                    anonProfile = try await anonService.fetchProfile(id: identity.profileId)
                } catch {
                    // Profile fetch failing shouldn't block anon mode.
                    anonProfile = fallbackAnonProfile(identity: identity)
                }
            } catch {
                anonErrorMessage = error.localizedDescription
                anonProfile = nil
            }
        } else {
            anonProfile = nil
            anonErrorMessage = nil
        }
    }
    
    func updateProfile(displayName: String?, bio: String? = nil, isAnonymous: Bool, showFollowerCount: Bool?) async {
        do {
            let updatedUser = try await userService.updateProfile(
                displayName: displayName,
                bio: bio,
                isAnonymous: isAnonymous,
                showFollowerCount: showFollowerCount
            )
            user = updatedUser

            userProfile = UserProfile.from(user: updatedUser, isCurrentUser: true)

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fallbackAnonProfile(identity: AnonIdentity) -> AnonProfile {
        AnonProfile(
            id: identity.profileId,
            handle: identity.handle,
            companyId: user?.companyId,
            followerCount: nil,
            followingCount: nil,
            postsCount: nil,
            createdAt: nil,
            updatedAt: nil,
            displayCommunity: nil
        )
    }
    
    func signOut() {
        authService.signOut()
        user = nil
        userProfile = nil
        userPosts = []
    }

    func loadUserPosts(limit: Int = 20) async {
        if anonService.isAnonymousEnabled {
            guard let identity = await anonService.currentIdentity() else {
                userPosts = []
                isLoadingPosts = false
                return
            }
            isLoadingPosts = true
            errorMessage = nil
            do {
                let page = try await feedService.fetchAnonPosts(
                    anonProfileId: identity.profileId,
                    limit: limit,
                    cursor: nil
                )
                userPosts = page.posts
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingPosts = false
            return
        }
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

    func removePost(backendId: Int?) {
        guard let backendId else { return }
        userPosts.removeAll { $0.backendId == backendId }
    }

    func updatePost(_ updated: Post) {
        guard let backendId = updated.backendId else { return }
        if let index = userPosts.firstIndex(where: { $0.backendId == backendId }) {
            userPosts[index] = updated
        }
    }
}
