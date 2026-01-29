import Foundation
import Combine
import UIKit

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
    private let mediaService: MediaServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        userService: UserServiceProtocol = UserService(),
        feedService: FeedServiceProtocol = FeedService(),
        authService: AuthServiceProtocol = AuthService(),
        anonService: AnonService = .shared,
        verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService(),
        mediaService: MediaServiceProtocol = MediaService()
    ) {
        self.userService = userService
        self.feedService = feedService
        self.authService = authService
        self.anonService = anonService
        self.verificationService = verificationService
        self.mediaService = mediaService
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
                    preferredSpecializationId: user?.displaySpecialization?.id,
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
    
    func updateProfile(
        displayName: String?,
        bio: String? = nil,
        isAnonymous: Bool,
        showFollowerCount: Bool?,
        messagePermission: MessagePermission? = nil
    ) async {
        do {
            let updatedUser = try await userService.updateProfile(
                displayName: displayName,
                bio: bio,
                isAnonymous: isAnonymous,
                showFollowerCount: showFollowerCount,
                messagePermission: messagePermission ?? user?.messagePermission
            )
            user = updatedUser

            userProfile = UserProfile.from(user: updatedUser, isCurrentUser: true)

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfileWithPhoto(
        displayName: String?,
        handle: String?,
        bio: String? = nil,
        isAnonymous: Bool,
        showFollowerCount: Bool?,
        messagePermission: MessagePermission? = nil,
        profileImage: UIImage?
    ) async {
        do {
            var workingUser = user
            let trimmedHandle = (handle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !isAnonymous,
               !trimmedHandle.isEmpty,
               let currentHandle = workingUser?.handle,
               currentHandle.lowercased() != trimmedHandle.lowercased() {
                guard
                    let firstName = workingUser?.firstName, !firstName.isEmpty,
                    let lastName = workingUser?.lastName, !lastName.isEmpty,
                    let dateOfBirth = workingUser?.dateOfBirth, !dateOfBirth.isEmpty
                else {
                    throw NSError(domain: "looped.profile", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "Missing required identity info to update your handle."
                    ])
                }
                let updatedIdentityUser = try await userService.updateIdentity(
                    username: trimmedHandle,
                    firstName: firstName,
                    lastName: lastName,
                    dateOfBirth: dateOfBirth
                )
                workingUser = updatedIdentityUser
                user = updatedIdentityUser
            }

            var profileMediaAssetId: Int?
            if !isAnonymous, let profileImage {
                let prepared = profileImage.normalizedOrientation().resized(maxDimension: 2048)
                guard let payload = makeUploadPayload(from: prepared) else {
                    throw NSError(domain: "looped.profile", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Couldn't prepare that profile photo. Try another one."
                    ])
                }
                let asset = try await mediaService.uploadImage(
                    data: payload.data,
                    mimeType: payload.mimeType,
                    width: payload.width,
                    height: payload.height
                )
                profileMediaAssetId = asset.id
            }

            let updatedUser = try await userService.updateProfile(
                displayName: displayName,
                bio: bio,
                isAnonymous: isAnonymous,
                showFollowerCount: showFollowerCount,
                messagePermission: messagePermission ?? workingUser?.messagePermission,
                profileMediaAssetId: profileMediaAssetId
            )
            user = updatedUser
            userProfile = UserProfile.from(user: updatedUser, isCurrentUser: true)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeUploadPayload(from image: UIImage) -> ImageUploadPayload? {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        if imageHasAlpha(image), let pngData = image.pngData() {
            return ImageUploadPayload(data: pngData, mimeType: "image/png", width: width, height: height)
        }

        if let jpegData = image.jpegData(compressionQuality: 0.85) {
            return ImageUploadPayload(data: jpegData, mimeType: "image/jpeg", width: width, height: height)
        }

        return nil
    }

    private func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
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
            showFollowerCount: nil,
            createdAt: nil,
            updatedAt: nil,
            displayCommunity: nil,
            displaySpecialization: nil
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

private struct ImageUploadPayload {
    let data: Data
    let mimeType: String
    let width: Int
    let height: Int
}
