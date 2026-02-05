import Foundation

enum UserProfileSource {
    case user(id: Int)
    case anon(id: Int)
}

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFollowing = false
    @Published var isFollowActionInFlight = false
    @Published var followErrorMessage: String?

    private let source: UserProfileSource
    private let currentUserId: Int?
    private let userService: UserServiceProtocol
    private let anonService: AnonService
    private let followStateStore: FollowStateStore

    var isAnonymousProfile: Bool {
        if case .anon = source { return true }
        return false
    }

    init(
        source: UserProfileSource,
        currentUserId: Int? = nil,
        initialProfile: UserProfile? = nil,
        userService: UserServiceProtocol = UserService(),
        anonService: AnonService? = nil,
        followStateStore: FollowStateStore? = nil
    ) {
        self.source = source
        self.currentUserId = currentUserId
        self.userService = userService
        self.anonService = anonService ?? .shared
        self.followStateStore = followStateStore ?? .shared
        self.profile = initialProfile

        switch source {
        case .user(let userId):
            self.isFollowing = self.followStateStore.isFollowing(userId: userId)
        case .anon(let anonProfileId):
            self.isFollowing = self.followStateStore.isFollowing(anonProfileId: anonProfileId)
        }
    }

    func loadProfile() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            switch source {
            case .user(let userId):
                let user = try await userService.getUser(by: userId)
                profile = UserProfile.from(user: user, isCurrentUser: user.backendId == currentUserId)
                isFollowing = followStateStore.isFollowing(userId: userId)
            case .anon(let anonProfileId):
                let anonProfile = try await anonService.fetchProfile(id: anonProfileId)
                let currentIdentity = await anonService.currentIdentity()
                let isCurrentUser = currentIdentity?.profileId == anonProfileId
                profile = anonProfile.asUserProfile(companyName: nil, isCurrentUser: isCurrentUser)
                isFollowing = followStateStore.isFollowing(anonProfileId: anonProfileId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleFollow(asAnonymousActor: Bool) async {
        guard !isFollowActionInFlight else { return }
        isFollowActionInFlight = true
        followErrorMessage = nil

        let wasFollowing = isFollowing
        let previousProfile = profile
        isFollowing.toggle()
        if let profile {
            let delta = wasFollowing ? -1 : 1
            self.profile = profile.updatingFollowersCount(max(0, profile.followersCount + delta))
        }

        do {
            let resolvedFollowing: Bool
            switch source {
            case .user(let userId):
                let result: UserFollowActionResult
                if wasFollowing {
                    result = try await userService.unfollowUser(
                        userId: userId,
                        asAnonymousActor: asAnonymousActor,
                        communityId: nil
                    )
                } else {
                    result = try await userService.followUser(
                        userId: userId,
                        asAnonymousActor: asAnonymousActor,
                        communityId: nil
                    )
                }
                resolvedFollowing = result.following
                followStateStore.setFollowing(result.following, userId: userId)
            case .anon(let anonProfileId):
                let result: AnonProfileFollowActionResult
                if wasFollowing {
                    result = try await userService.unfollowAnonProfile(
                        anonProfileId: anonProfileId,
                        asAnonymousActor: asAnonymousActor,
                        communityId: nil
                    )
                } else {
                    result = try await userService.followAnonProfile(
                        anonProfileId: anonProfileId,
                        asAnonymousActor: asAnonymousActor,
                        communityId: nil
                    )
                }
                resolvedFollowing = result.following
                followStateStore.setFollowing(result.following, anonProfileId: anonProfileId)
            }
            isFollowing = resolvedFollowing
            if let previousProfile {
                let delta = (resolvedFollowing ? 1 : 0) - (wasFollowing ? 1 : 0)
                let corrected = max(0, previousProfile.followersCount + delta)
                profile = previousProfile.updatingFollowersCount(corrected)
            }
        } catch {
            isFollowing = wasFollowing
            profile = previousProfile
            followErrorMessage = followErrorMessage(from: error, wasFollowing: wasFollowing)
        }

        isFollowActionInFlight = false
    }

    private func followErrorMessage(from error: Error, wasFollowing: Bool) -> String {
        let verb = wasFollowing ? "unfollow" : "follow"
        guard case let APIError.apiError(_, apiError, message) = error else {
            return "Couldn't \(verb) user. \(error.localizedDescription)"
        }

        switch apiError {
        case "not_found":
            return "That user no longer exists."
        case "invalid_target":
            return "You can’t follow that user."
        case "forbidden":
            return "You can’t follow that profile."
        case "user_not_provisioned":
            return "Finish setting up your account to follow people."
        case "unauthorized":
            return "Please sign in to follow people."
        case "invalid_actor":
            return "Anonymous follow requires the X-Actor: anon header."
        case "anon_jwt_not_allowed":
            return "Anonymous follow can’t use an authenticated session."
        case "invalid_anon_proof":
            return "Anonymous proof expired or invalid. Try again."
        default:
            return "Couldn't \(verb) user. \(message ?? apiError)"
        }
    }
}
