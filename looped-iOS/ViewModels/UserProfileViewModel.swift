import Foundation

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userId: Int
    private let currentUserId: Int?
    private let userService: UserServiceProtocol

    init(
        userId: Int,
        currentUserId: Int? = nil,
        initialProfile: UserProfile? = nil,
        userService: UserServiceProtocol = UserService()
    ) {
        self.userId = userId
        self.currentUserId = currentUserId
        self.userService = userService
        self.profile = initialProfile
    }

    func loadProfile() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let user = try await userService.getUser(by: userId)
            profile = UserProfile.from(user: user, isCurrentUser: user.backendId == currentUserId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
