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
}
