import Foundation

@MainActor
final class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [BlockedUser] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var actionErrorMessage: String?
    @Published var unblockingPrincipalIds: Set<Int> = []

    private let blockService: BlockServiceProtocol
    private var nextCursor: String?

    init(blockService: BlockServiceProtocol = BlockService()) {
        self.blockService = blockService
    }

    func loadBlockedUsers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await blockService.fetchBlockedUsers(limit: 20, cursor: nil)
            blockedUsers = page.users
            nextCursor = page.nextCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        nextCursor = nil
        await loadBlockedUsers()
    }

    func loadMoreIfNeeded(current user: BlockedUser) async {
        guard let nextCursor, !isLoadingMore else { return }
        guard user.id == blockedUsers.last?.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await blockService.fetchBlockedUsers(limit: 20, cursor: nextCursor)
            blockedUsers.append(contentsOf: page.users)
            self.nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unblock(_ user: BlockedUser) async {
        guard !unblockingPrincipalIds.contains(user.principalId) else { return }
        unblockingPrincipalIds.insert(user.principalId)
        defer { unblockingPrincipalIds.remove(user.principalId) }
        do {
            _ = try await blockService.unblockPrincipal(principalId: user.principalId, asAnonymousActor: false, communityId: nil)
            blockedUsers.removeAll { $0.principalId == user.principalId }
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
}
