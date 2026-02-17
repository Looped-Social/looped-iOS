import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct BlockedUsersViewModelTests {

    @Test
    func loadBlockedUsers_success_populatesList() async {
        let service = MockBlockService()
        service.fetchBlockedUsersHandler = { _, _ in
            BlockedUsersPage(users: [
                TestFixtures.blockedUser(principalId: 101, backendId: 1),
                TestFixtures.blockedUser(principalId: 102, backendId: 2)
            ], nextCursor: nil)
        }

        let viewModel = BlockedUsersViewModel(blockService: service)
        await viewModel.loadBlockedUsers()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.blockedUsers.count == 2)
    }

    @Test
    func loadBlockedUsers_error_setsMessage() async {
        let service = MockBlockService()
        service.fetchBlockedUsersHandler = { _, _ in
            throw TestError(message: "load failed")
        }

        let viewModel = BlockedUsersViewModel(blockService: service)
        await viewModel.loadBlockedUsers()

        #expect(viewModel.blockedUsers.isEmpty)
        #expect(viewModel.errorMessage == "load failed")
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadMoreIfNeeded_appendsNextPageWhenCurrentIsLast() async {
        let service = MockBlockService()
        service.fetchBlockedUsersHandler = { _, cursor in
            if cursor == nil {
                return BlockedUsersPage(users: [TestFixtures.blockedUser(principalId: 201, backendId: 1)], nextCursor: "next")
            }
            return BlockedUsersPage(users: [TestFixtures.blockedUser(principalId: 202, backendId: 2)], nextCursor: nil)
        }

        let viewModel = BlockedUsersViewModel(blockService: service)
        await viewModel.loadBlockedUsers()
        guard let first = viewModel.blockedUsers.first else {
            Issue.record("Expected at least one blocked user after load")
            return
        }

        await viewModel.loadMoreIfNeeded(current: first)

        #expect(viewModel.blockedUsers.count == 2)
        #expect(service.fetchBlockedUsersCalls.count == 2)
    }

    @Test
    func loadMoreIfNeeded_noopWhenCurrentIsNotLast() async {
        let service = MockBlockService()
        service.fetchBlockedUsersHandler = { _, cursor in
            if cursor == nil {
                return BlockedUsersPage(users: [
                    TestFixtures.blockedUser(principalId: 301, backendId: 1),
                    TestFixtures.blockedUser(principalId: 302, backendId: 2)
                ], nextCursor: "next")
            }
            return BlockedUsersPage(users: [TestFixtures.blockedUser(principalId: 303, backendId: 3)], nextCursor: nil)
        }

        let viewModel = BlockedUsersViewModel(blockService: service)
        await viewModel.loadBlockedUsers()

        await viewModel.loadMoreIfNeeded(current: viewModel.blockedUsers[0])

        #expect(viewModel.blockedUsers.count == 2)
        #expect(service.fetchBlockedUsersCalls.count == 1)
    }

    @Test
    func unblock_success_removesUserAndPreventsDuplicateInFlightCalls() async {
        let service = MockBlockService()
        service.fetchBlockedUsersHandler = { _, _ in
            BlockedUsersPage(users: [TestFixtures.blockedUser(principalId: 401, backendId: 1)], nextCursor: nil)
        }
        service.unblockPrincipalHandler = { principalId, _, _ in
            try await Task.sleep(nanoseconds: 150_000_000)
            return PrincipalBlockActionResult(principalId: principalId, blocked: false)
        }

        let viewModel = BlockedUsersViewModel(blockService: service)
        await viewModel.loadBlockedUsers()
        guard let user = viewModel.blockedUsers.first else {
            Issue.record("Expected blocked user before unblock")
            return
        }

        async let first: Void = viewModel.unblock(user)
        async let second: Void = viewModel.unblock(user)
        _ = await (first, second)

        #expect(service.unblockPrincipalCalls.count == 1)
        #expect(viewModel.blockedUsers.isEmpty)
        #expect(viewModel.unblockingPrincipalIds.isEmpty)
    }

    @Test
    func unblock_failure_setsActionErrorAndPreservesUser() async {
        let service = MockBlockService()
        let user = TestFixtures.blockedUser(principalId: 501, backendId: 1)
        service.fetchBlockedUsersHandler = { _, _ in
            BlockedUsersPage(users: [user], nextCursor: nil)
        }
        service.unblockPrincipalHandler = { _, _, _ in
            throw TestError(message: "unblock failed")
        }

        let viewModel = BlockedUsersViewModel(blockService: service)
        await viewModel.loadBlockedUsers()
        await viewModel.unblock(user)

        #expect(viewModel.blockedUsers.count == 1)
        #expect(viewModel.actionErrorMessage == "unblock failed")
    }

    @Test
    func refresh_retriesAfterErrorAndLoadsData() async {
        let service = MockBlockService()
        var call = 0
        service.fetchBlockedUsersHandler = { _, _ in
            defer { call += 1 }
            if call == 0 {
                throw TestError(message: "temporary")
            }
            return BlockedUsersPage(users: [TestFixtures.blockedUser(principalId: 601, backendId: 1)], nextCursor: nil)
        }

        let viewModel = BlockedUsersViewModel(blockService: service)

        await viewModel.loadBlockedUsers()
        #expect(viewModel.errorMessage == "temporary")

        await viewModel.refresh()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.blockedUsers.count == 1)
    }
}
