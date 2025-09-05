import Foundation
import Combine

@MainActor
class MessagesViewModel: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let messageService: MessageServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(messageService: MessageServiceProtocol = MockConfig.useMockData ? MockMessageService() : MessageService()) {
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
        messageService: MessageServiceProtocol = MockConfig.useMockData ? MockMessageService() : MessageService(),
        webSocketService: WebSocketServiceProtocol = MockConfig.useMockData ? MockWebSocketService() : WebSocketService()
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
    
    func sendMessage(_ content: String, to channel: Channel) async {
        do {
            try await messageService.sendMessage(content: content, channelId: channel.id)
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