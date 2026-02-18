import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct NewMessageSearchViewModelTests {

    @Test
    func search_filtersBlockedUsers() async {
        let userService = MockUserService()
        userService.searchUsersHandler = { _, _, _ in
            UserSearchPage(
                users: [
                    TestFixtures.user(backendId: 2001, handle: "blocked"),
                    TestFixtures.user(backendId: 2002, handle: "visible")
                ],
                nextCursor: nil
            )
        }

        let blockService = MockBlockService()
        blockService.fetchBlockedUsersHandler = { _, _ in
            BlockedUsersPage(users: [TestFixtures.blockedUser(principalId: 9001, backendId: 2001)], nextCursor: nil)
        }

        let viewModel = NewMessageSearchViewModel(
            userService: userService,
            blockService: blockService
        )

        await viewModel.search(query: "hello")

        #expect(viewModel.results.map(\.backendId) == [2002])
    }
}

