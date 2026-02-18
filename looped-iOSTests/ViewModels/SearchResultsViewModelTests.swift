import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct SearchResultsViewModelTests {

    @Test
    func performSearch_usersFilter_excludesBlockedUsers() async {
        let userService = MockUserService()
        userService.searchUsersHandler = { _, _, _ in
            UserSearchPage(
                users: [
                    TestFixtures.user(backendId: 1001, handle: "blocked"),
                    TestFixtures.user(backendId: 1002, handle: "visible")
                ],
                nextCursor: nil
            )
        }

        let blockService = MockBlockService()
        blockService.fetchBlockedUsersHandler = { _, _ in
            BlockedUsersPage(users: [TestFixtures.blockedUser(principalId: 5001, backendId: 1001)], nextCursor: nil)
        }

        let viewModel = SearchResultsViewModel(
            userService: userService,
            blockService: blockService
        )

        await viewModel.performSearch(query: "user", filter: .users)

        #expect(viewModel.searchResults.people.compactMap(\.backendId) == [1002])
        #expect(viewModel.errorMessage == nil)
    }
}

