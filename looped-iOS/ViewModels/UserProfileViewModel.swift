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

    var isAnonymousProfile: Bool {
        if case .anon = source { return true }
        return false
    }

    init(
        source: UserProfileSource,
        currentUserId: Int? = nil,
        initialProfile: UserProfile? = nil,
        userService: UserServiceProtocol = UserService(),
        anonService: AnonService = .shared
    ) {
        self.source = source
        self.currentUserId = currentUserId
        self.userService = userService
        self.anonService = anonService
        self.profile = initialProfile
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
            case .anon(let anonProfileId):
                let anonProfile = try await anonService.fetchProfile(id: anonProfileId)
                profile = anonProfile.asUserProfile(companyName: nil, isCurrentUser: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleFollow(asAnonymousActor: Bool) async {
        guard case .user(let userId) = source else { return }
        guard !isFollowActionInFlight else { return }
        isFollowActionInFlight = true
        followErrorMessage = nil

        let wasFollowing = isFollowing
        isFollowing.toggle()

        do {
            let result: UserFollowActionResult
            if wasFollowing {
                result = try await userService.unfollowUser(userId: userId, asAnonymousActor: asAnonymousActor, communityId: nil)
            } else {
                result = try await userService.followUser(userId: userId, asAnonymousActor: asAnonymousActor, communityId: nil)
            }
            isFollowing = result.following
        } catch {
            isFollowing = wasFollowing
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
        case "user_not_provisioned":
            return "Finish setting up your account to follow people."
        case "unauthorized":
            return "Please sign in to follow people."
        case "anon_jwt_not_allowed":
            return "Anonymous follow can’t use an authenticated session."
        case "invalid_anon_proof":
            return "Anonymous proof expired or invalid. Try again."
        default:
            return "Couldn't \(verb) user. \(message ?? apiError)"
        }
    }
}
