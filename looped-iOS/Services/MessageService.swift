import Foundation

class MessageService: MessageServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func getChannels() async throws -> [Channel] {
        return try await apiClient.get("/messages/channels")
    }
    
    func getMessages(channelId: UUID) async throws -> [Message] {
        return try await apiClient.get("/messages/channels/\(channelId)/messages")
    }
    
    func sendMessage(content: String, channelId: UUID) async throws -> Message {
        let request = SendMessageRequest(content: content, channelId: channelId, messageType: .channel)
        return try await apiClient.post("/messages", body: request)
    }
    
    func sendDirectMessage(content: String, receiverId: UUID) async throws -> Message {
        let request = SendDirectMessageRequest(content: content, receiverId: receiverId, messageType: .direct)
        return try await apiClient.post("/messages", body: request)
    }
}

private struct SendMessageRequest: Codable {
    let content: String
    let channelId: UUID
    let messageType: MessageType
}

private struct SendDirectMessageRequest: Codable {
    let content: String
    let receiverId: UUID
    let messageType: MessageType
}