import Foundation

@MainActor
final class MessagingPermissionsViewModel: ObservableObject {
    @Published var selectedPermission: MessagePermission = .all
    @Published var isSaving = false
    @Published var updatingPermission: MessagePermission?
    @Published var errorMessage: String?

    private let userService: UserServiceProtocol
    private var confirmedPermission: MessagePermission = .all

    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }

    func load(from user: User?) {
        let permission = user?.messagePermission ?? .all
        selectedPermission = permission
        confirmedPermission = permission
        errorMessage = nil
    }

    func updatePermission(_ permission: MessagePermission, currentUser: User?) async -> User? {
        guard permission != confirmedPermission else { return nil }
        guard !isSaving else { return nil }
        guard let currentUser else {
            errorMessage = "Unable to load your profile."
            return nil
        }
        isSaving = true
        errorMessage = nil
        updatingPermission = permission
        selectedPermission = permission
        defer {
            isSaving = false
            updatingPermission = nil
        }
        do {
            let updatedUser = try await userService.updateProfile(
                displayName: nil,
                bio: nil,
                isAnonymous: currentUser.isAnonymous,
                showFollowerCount: currentUser.showFollowerCount,
                messagePermission: permission
            )
            confirmedPermission = permission
            errorMessage = nil
            return updatedUser
        } catch {
            selectedPermission = confirmedPermission
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
