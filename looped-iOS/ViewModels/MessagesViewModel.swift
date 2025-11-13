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
            let fetchedChannels = try await messageService.getChannels()
            channels = fetchedChannels
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadConversations() async {
        isLoading = true
        errorMessage = nil

        // Simulate network delay for realistic loading experience
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // For now, use mock data. In production, this would call an API
        conversations = MockConversations.conversations

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
    
    init(
        messageService: MessageServiceProtocol = MessageService(),
        webSocketService: WebSocketServiceProtocol = WebSocketService()
    ) {
        self.messageService = messageService
        self.webSocketService = webSocketService
        setupWebSocketListeners()
    }
    
    func loadMessages(for channel: Channel) async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedMessages = try await messageService.getMessages(channelId: channel.id)
            messages = fetchedMessages.sorted { $0.createdAt < $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadDirectMessages(with userId: UUID) async {
        isLoading = true
        errorMessage = nil

        // For now, use mock data for direct messages
        messages = MockMessages.getDirectMessages().sorted { $0.createdAt < $1.createdAt }

        isLoading = false
    }

    func sendMessage(_ content: String, to channel: Channel) async {
        do {
            try await messageService.sendMessage(content: content, channelId: channel.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendDirectMessage(_ content: String, to userId: UUID) async {
        // For now, simulate sending a direct message
        let newMessage = MockMessages.sendDirectMessage(content: content, to: userId)
        messages.append(newMessage)
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
