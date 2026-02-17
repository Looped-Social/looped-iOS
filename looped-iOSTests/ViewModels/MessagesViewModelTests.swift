import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct MessagesViewModelTests {

    @Test
    func loadInbox_success_populatesConversationsRequestsAndChannels() async {
        let service = MockMessageService()
        service.listConversationsHandler = { _ in
            ConversationPage(conversations: [TestFixtures.conversation(backendId: 10, isMuted: true)], nextCursor: nil)
        }
        service.fetchMessageRequestsHandler = { _ in
            MessageRequestPage(requests: [
                TestFixtures.messageRequest(backendId: 1, senderBackendId: nil, status: .pending),
                TestFixtures.messageRequest(backendId: 2, senderBackendId: nil, status: .approved)
            ], nextCursor: nil)
        }
        service.getChannelsHandler = { _ in
            ChannelPage(channels: [TestFixtures.channel(backendId: 8, name: "General")], nextCursor: nil)
        }

        let viewModel = MessagesViewModel(messageService: service, userService: UserService())

        await viewModel.loadInbox()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.isLoadingChannels == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.channelErrorMessage == nil)
        #expect(viewModel.conversations.count == 1)
        #expect(viewModel.messageRequests.count == 1)
        #expect(viewModel.channels.count == 1)
    }

    @Test
    func loadInbox_failure_setsErrorAndChannelError() async {
        let service = MockMessageService()
        service.listConversationsHandler = { _ in throw TestError(message: "conversation fail") }
        service.fetchMessageRequestsHandler = { _ in throw TestError(message: "request fail") }
        service.getChannelsHandler = { _ in throw TestError(message: "channel fail") }

        let viewModel = MessagesViewModel(messageService: service, userService: UserService())

        await viewModel.loadInbox()

        #expect(viewModel.errorMessage == "conversation fail")
        #expect(viewModel.channelErrorMessage == "channel fail")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isLoadingChannels == false)
    }

    @Test
    func approveMessageRequest_success_removesRequestAndReturnsConversation() async {
        let service = MockMessageService()
        service.approveRequestHandler = { _ in }

        let viewModel = MessagesViewModel(messageService: service, userService: UserService())
        let conversation = TestFixtures.conversation(backendId: 100, userName: "Existing")
        let request = TestFixtures.messageRequest(backendId: 50, senderBackendId: nil, conversationBackendId: 100)

        viewModel.conversations = [conversation]
        viewModel.messageRequests = [request]

        let resolved = await viewModel.approveMessageRequest(request)

        #expect(resolved?.backendId == 100)
        #expect(viewModel.messageRequests.isEmpty)
        #expect(viewModel.conversations.first?.backendId == 100)
        #expect(viewModel.processingRequestIds.isEmpty)
        #expect(service.approveRequestCalls == [50])
    }

    @Test
    func approveMessageRequest_failure_keepsRequestAndSetsError() async {
        let service = MockMessageService()
        service.approveRequestHandler = { _ in throw TestError(message: "approve failed") }

        let viewModel = MessagesViewModel(messageService: service, userService: UserService())
        let request = TestFixtures.messageRequest(backendId: 60, senderBackendId: nil, conversationBackendId: 101)
        viewModel.messageRequests = [request]

        let resolved = await viewModel.approveMessageRequest(request)

        #expect(resolved == nil)
        #expect(viewModel.messageRequests.count == 1)
        #expect(viewModel.errorMessage == "approve failed")
        #expect(viewModel.processingRequestIds.isEmpty)
    }

    @Test
    func rejectMessageRequest_success_removesRequest() async {
        let service = MockMessageService()
        service.rejectRequestHandler = { _ in }

        let viewModel = MessagesViewModel(messageService: service, userService: UserService())
        let request = TestFixtures.messageRequest(backendId: 70)
        viewModel.messageRequests = [request]

        await viewModel.rejectMessageRequest(request)

        #expect(viewModel.messageRequests.isEmpty)
        #expect(viewModel.processingRequestIds.isEmpty)
        #expect(service.rejectRequestCalls == [70])
    }

    @Test
    func searchMessages_success_updatesResults() async {
        let service = MockMessageService()
        let hit = TestFixtures.messageSearchConversationHit(
            id: "1",
            conversation: TestFixtures.conversation(backendId: 12)
        )
        service.searchMessagesHandler = { _, _, _ in
            MessageSearchPage(items: [hit], nextCursor: nil)
        }

        let viewModel = MessagesViewModel(messageService: service, userService: UserService())

        viewModel.searchMessages(query: "hello")
        await waitFor {
            viewModel.isSearching == false && viewModel.searchResults.count == 1
        }

        #expect(viewModel.searchResults.first?.id == "1")
        #expect(viewModel.searchErrorMessage == nil)
    }

    @Test
    func searchMessages_failure_setsSearchError() async {
        let service = MockMessageService()
        service.searchMessagesHandler = { _, _, _ in
            throw TestError(message: "search failed")
        }

        let viewModel = MessagesViewModel(messageService: service, userService: UserService())

        viewModel.searchMessages(query: "hello")
        await waitFor {
            viewModel.isSearching == false && viewModel.searchErrorMessage == "search failed"
        }

        #expect(viewModel.searchResults.isEmpty)
    }

    @Test
    func searchMessages_inAnonymousMode_blocksSearchAndSkipsService() async {
        UserDefaults.standard.set(true, forKey: "anonymousMode")
        defer { UserDefaults.standard.set(false, forKey: "anonymousMode") }

        let service = MockMessageService()
        let viewModel = MessagesViewModel(messageService: service, userService: UserService())

        viewModel.searchMessages(query: "hello")

        #expect(viewModel.searchErrorMessage == "Message search isn’t available in anonymous mode.")
        #expect(viewModel.searchResults.isEmpty)
        #expect(service.searchMessagesCalls.isEmpty)
    }

    @Test
    func searchMessages_cancellation_keepsLatestQueryResults() async {
        let service = MockMessageService()
        service.searchMessagesHandler = { query, _, _ in
            if query == "first" {
                try await Task.sleep(nanoseconds: 400_000_000)
                return MessageSearchPage(items: [
                    TestFixtures.messageSearchConversationHit(id: "old", conversation: TestFixtures.conversation(backendId: 1))
                ], nextCursor: nil)
            }

            return MessageSearchPage(items: [
                TestFixtures.messageSearchConversationHit(id: "new", conversation: TestFixtures.conversation(backendId: 2))
            ], nextCursor: nil)
        }

        let viewModel = MessagesViewModel(messageService: service, userService: UserService())

        viewModel.searchMessages(query: "first")
        try? await Task.sleep(nanoseconds: 40_000_000)
        viewModel.searchMessages(query: "second")

        await waitFor {
            viewModel.isSearching == false && viewModel.searchResults.first?.id == "new"
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        #expect(viewModel.searchResults.map(\.id) == ["new"])
    }
}

@MainActor
private func waitFor(
    timeout: TimeInterval = 2.0,
    condition: @escaping @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}
