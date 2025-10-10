import Foundation
import Combine

class WebSocketService: NSObject, WebSocketServiceProtocol {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let tokenStorage: TokenStorage
    
    @Published private var _connectionState: WebSocketConnectionState = .disconnected
    private let _messageReceived = PassthroughSubject<Message, Never>()
    
    var connectionState: AnyPublisher<WebSocketConnectionState, Never> {
        $_connectionState.eraseToAnyPublisher()
    }
    
    var messageReceived: AnyPublisher<Message, Never> {
        _messageReceived.eraseToAnyPublisher()
    }
    
    init(tokenStorage: TokenStorage = TokenStorage()) {
        self.tokenStorage = tokenStorage
        super.init()
        setupURLSession()
    }
    
    func connect() async {
        guard let token = tokenStorage.token else { return }
        
        _connectionState = .connecting
        
        let url = URL(string: "wss://api.looped.app/ws")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        startListening()
        _connectionState = .connected
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        _connectionState = .disconnected
    }
    
    func joinChannel(_ channelId: UUID) {
        let message = WebSocketMessage(
            type: "join_channel",
            payload: ["channelId": channelId.uuidString]
        )
        sendMessage(message)
    }
    
    func leaveChannel(_ channelId: UUID) {
        let message = WebSocketMessage(
            type: "leave_channel",
            payload: ["channelId": channelId.uuidString]
        )
        sendMessage(message)
    }
    
    private func setupURLSession() {
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    private func startListening() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.startListening()
            case .failure(let error):
                self?._connectionState = .error(error)
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8),
               let wsMessage = try? JSONDecoder().decode(WebSocketMessage.self, from: data) {
                processWebSocketMessage(wsMessage)
            }
        case .data(let data):
            if let wsMessage = try? JSONDecoder().decode(WebSocketMessage.self, from: data) {
                processWebSocketMessage(wsMessage)
            }
        @unknown default:
            break
        }
    }
    
    private func processWebSocketMessage(_ wsMessage: WebSocketMessage) {
        switch wsMessage.type {
        case "new_message":
            // For mock purposes, we'll create a simple message
            // In production, this would parse the actual message data from the payload
            if let content = wsMessage.payload["content"],
               let senderId = wsMessage.payload["senderId"],
               let senderDisplayName = wsMessage.payload["senderDisplayName"] {
                let message = Message(
                    id: UUID(),
                    content: content,
                    senderId: UUID(uuidString: senderId) ?? UUID(),
                    senderDisplayName: senderDisplayName,
                    receiverId: nil,
                    channelId: UUID(uuidString: wsMessage.payload["channelId"] ?? "") ?? UUID(),
                    messageType: .channel,
                    isRead: false,
                    attachments: nil,
                    createdAt: Date()
                )
                _messageReceived.send(message)
            }
        default:
            break
        }
    }
    
    private func sendMessage(_ message: WebSocketMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let string = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(string)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
}

extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        _connectionState = .connected
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        _connectionState = .disconnected
    }
}

private struct WebSocketMessage: Codable {
    let type: String
    let payload: [String: String] // Simplified to String values only
    
    init(type: String, payload: [String: String]) {
        self.type = type
        self.payload = payload
    }
}

