import Foundation
import Combine

@MainActor
class MessagesViewModel: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let messageService: MessageServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(messageService: MessageServiceProtocol = MessageService()) {
        self.messageService = messageService
    }

    func loadChannels() async {
        isLoading = true
        errorMessage = nil

        do {
            let page = try await messageService.getChannels(cursor: nil)
            channels = page.channels
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadConversations() async {
        isLoading = true
        errorMessage = nil

        do {
            let page = try await messageService.listConversations(cursor: nil)
            conversations = page.conversations
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refreshConversations() async {
        await loadConversations()
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let messageService: MessageServiceProtocol
    private let webSocketService: WebSocketServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var conversationBackendId: Int?
    private var channelBackendId: Int?
    private var nextCursor: String?
    
    init(
        messageService: MessageServiceProtocol = MessageService(),
        webSocketService: WebSocketServiceProtocol = WebSocketService()
    ) {
        self.messageService = messageService
        self.webSocketService = webSocketService
        setupWebSocketListeners()
    }
    
    func configure(conversationBackendId: Int? = nil, channelBackendId: Int? = nil) {
        self.conversationBackendId = conversationBackendId
        self.channelBackendId = channelBackendId
    }
    
    func loadMessages(for channel: Channel) async {
        isLoading = true
        errorMessage = nil

        do {
            let page = try await messageService.getChannelMessages(channelBackendId: channel.backendId, cursor: nil)
            messages = page.messages
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadDirectMessages() async {
        isLoading = true
        errorMessage = nil

        guard let conversationBackendId else {
            errorMessage = "Direct messages require a conversation ID."
            isLoading = false
            return
        }

        do {
            let page = try await messageService.getConversationMessages(conversationId: conversationBackendId, cursor: nil)
            messages = page.messages
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendMessage(_ content: String, to channel: Channel) async {
        do {
            _ = try await messageService.sendChannelMessage(channelBackendId: channel.backendId, content: content)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendDirectMessage(_ content: String) async {
        guard let conversationBackendId else {
            errorMessage = "Direct messages require a conversation ID."
            return
        }
        do {
            let message = try await messageService.sendConversationMessage(conversationId: conversationBackendId, content: content)
            messages.append(message)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func setupWebSocketListeners() {
        webSocketService.messageReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.messages.append(message)
            }
            .store(in: &cancellables)
    }
}
