import Foundation

class MessageService: MessageServiceProtocol {
    private let apiClient: APIClient
    private struct EmptyBody: Codable {}
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func listConversations(cursor: String?) async throws -> ConversationPage {
        var endpoint = "/v1/conversations?limit=20"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: ConversationListResponseDTO = try await apiClient.get(endpoint)
        let conversations = response.items.map { dto in
            Conversation(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                userId: UUID.fromBackendId(dto.otherUserProfile.id),
                backendUserId: dto.otherUserProfile.id,
                userName: dto.otherUserProfile.displayName ?? dto.otherUserProfile.handle,
                userProfileImageUrl: dto.otherUserProfile.profileImageUrl,
                lastMessage: dto.lastMessage ?? "",
                lastMessageTimestamp: dto.lastMessageTimestamp ?? Date(),
                unreadCount: dto.unreadCount,
                hasTypingIndicator: false,
                hasSpecialStatus: false,
                isOnline: false,
                isGroup: false,
                memberIds: nil
            )
        }
        return ConversationPage(conversations: conversations, nextCursor: response.nextCursor)
    }
    
    func startConversation(with participantBackendId: Int) async throws -> Conversation {
        struct StartConversationRequest: Codable { let participantUserId: Int }
        let dto: ConversationDTO = try await apiClient.post("/v1/conversations", body: StartConversationRequest(participantUserId: participantBackendId))
        return Conversation(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            userId: UUID.fromBackendId(dto.otherUserProfile.id),
            backendUserId: dto.otherUserProfile.id,
            userName: dto.otherUserProfile.displayName ?? dto.otherUserProfile.handle,
            userProfileImageUrl: dto.otherUserProfile.profileImageUrl,
            lastMessage: dto.lastMessage ?? "",
            lastMessageTimestamp: dto.lastMessageTimestamp ?? Date(),
            unreadCount: dto.unreadCount,
            hasTypingIndicator: false,
            hasSpecialStatus: false,
            isOnline: false,
            isGroup: false,
            memberIds: nil
        )
    }
    
    func getConversationMessages(conversationId: Int, cursor: String?) async throws -> MessagePage {
        var endpoint = "/v1/conversations/\(conversationId)/messages?limit=50"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: MessageListResponseDTO = try await apiClient.get(endpoint)
        let messages = response.items.map { dto in
            Message(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                content: dto.content,
                senderId: UUID.fromBackendId(dto.senderId),
                senderDisplayName: nil,
                receiverId: nil,
                conversationBackendId: conversationId,
                channelBackendId: nil,
                messageType: .direct,
                isRead: false,
                attachments: dto.attachments?.map(MediaAttachment.init(dto:)),
                createdAt: dto.createdAt
            )
        }
        return MessagePage(messages: messages.sorted { $0.createdAt < $1.createdAt }, nextCursor: response.nextCursor)
    }
    
    func sendConversationMessage(conversationId: Int, content: String) async throws -> Message {
        let request = SendMessageRequestDTO(content: content, attachments: nil)
        let dto: MessageDTO = try await apiClient.post("/v1/conversations/\(conversationId)/messages", body: request)
        return Message(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            content: dto.content,
            senderId: UUID.fromBackendId(dto.senderId),
            senderDisplayName: nil,
            receiverId: nil,
            conversationBackendId: conversationId,
            channelBackendId: nil,
            messageType: .direct,
            isRead: false,
            attachments: dto.attachments?.map(MediaAttachment.init(dto:)),
            createdAt: dto.createdAt
        )
    }
    
    func getChannels(cursor: String?) async throws -> ChannelPage {
        var endpoint = "/v1/channels?limit=20"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: ChannelListResponseDTO = try await apiClient.get(endpoint)
        let channels = response.items.map { dto in
            Channel(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                name: dto.name,
                company: "",
                memberCount: dto.memberCount,
                isPublic: dto.isPublic,
                createdAt: dto.createdAt
            )
        }
        return ChannelPage(channels: channels, nextCursor: response.nextCursor)
    }
    
    func getChannelMessages(channelBackendId: Int, cursor: String?) async throws -> MessagePage {
        var endpoint = "/v1/channels/\(channelBackendId)/messages?limit=50"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: MessageListResponseDTO = try await apiClient.get(endpoint)
        let messages = response.items.map { dto in
            Message(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                content: dto.content,
                senderId: UUID.fromBackendId(dto.senderId),
                senderDisplayName: nil,
                receiverId: nil,
                conversationBackendId: nil,
                channelBackendId: channelBackendId,
                messageType: .channel,
                isRead: false,
                attachments: dto.attachments?.map(MediaAttachment.init(dto:)),
                createdAt: dto.createdAt
            )
        }
        return MessagePage(messages: messages.sorted { $0.createdAt < $1.createdAt }, nextCursor: response.nextCursor)
    }
    
    func sendChannelMessage(channelBackendId: Int, content: String) async throws -> Message {
        let request = SendMessageRequestDTO(content: content, attachments: nil)
        let dto: MessageDTO = try await apiClient.post("/v1/channels/\(channelBackendId)/messages", body: request)
        return Message(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            content: dto.content,
            senderId: UUID.fromBackendId(dto.senderId),
            senderDisplayName: nil,
            receiverId: nil,
            conversationBackendId: nil,
            channelBackendId: channelBackendId,
            messageType: .channel,
            isRead: false,
            attachments: dto.attachments?.map(MediaAttachment.init(dto:)),
            createdAt: dto.createdAt
        )
    }

    func fetchMessageRequests(cursor: String?) async throws -> MessageRequestPage {
        var endpoint = "/v1/message-requests?limit=20"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: MessageRequestListResponseDTO = try await apiClient.get(endpoint)
        let requests = response.items.map { dto in
            let preview = dto.preview
            let attachments = preview?.attachments?.map(MediaAttachment.init(dto:)) ?? []
            let senderName = dto.senderProfile?.displayName ?? dto.senderProfile?.handle
            return MessageRequest(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                senderBackendId: dto.senderId,
                senderName: senderName,
                senderHandle: dto.senderProfile?.handle,
                senderProfileImageUrl: dto.senderProfile?.profileImageUrl,
                previewText: preview?.content ?? "",
                previewAttachments: attachments,
                previewCreatedAt: preview?.createdAt ?? Date(),
                status: dto.status ?? .pending,
                conversationBackendId: dto.conversationId,
                channelBackendId: dto.channelId,
                isGroup: dto.isGroup ?? false
            )
        }
        return MessageRequestPage(requests: requests, nextCursor: response.nextCursor)
    }

    func approveMessageRequest(requestId: Int) async throws {
        let _: EmptyResponse = try await apiClient.post(
            "/v1/message-requests/\(requestId)/approve",
            body: EmptyBody()
        )
    }

    func rejectMessageRequest(requestId: Int) async throws {
        let _: EmptyResponse = try await apiClient.post(
            "/v1/message-requests/\(requestId)/reject",
            body: EmptyBody()
        )
    }
}
