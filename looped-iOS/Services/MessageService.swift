import Foundation

class MessageService: MessageServiceProtocol {
    private let apiClient: APIClient
    private struct EmptyBody: Codable {}
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func listConversations(cursor: String?) async throws -> ConversationPage {
        var endpoint = "/v1/conversations?limit=50"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: ConversationListResponseDTO = try await apiClient.get(endpoint)
        let conversations = response.items.compactMap { dto -> Conversation? in
            guard let profile = dto.otherUserProfile else {
                #if DEBUG
                print("Skipping conversation \(dto.id) due to missing otherUserProfile")
                #endif
                return nil
            }
            return Conversation(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                userId: UUID.fromBackendId(profile.id),
                backendUserId: profile.id,
                userName: profile.displayName ?? profile.handle,
                userProfileImageUrl: profile.profileImageUrl,
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
        #if DEBUG
        print("Conversations fetched: \(conversations.count) ids=\(conversations.map { $0.backendId })")
        #endif
        return ConversationPage(conversations: conversations, nextCursor: response.nextCursor)
    }
    
    func startConversation(with participantBackendId: Int) async throws -> Conversation {
        struct StartConversationRequest: Codable { let participantUserId: Int }
        let dto: ConversationDTO = try await apiClient.post("/v1/conversations", body: StartConversationRequest(participantUserId: participantBackendId))
        guard let profile = dto.otherUserProfile else {
            throw APIError.invalidResponse
        }
        return Conversation(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            userId: UUID.fromBackendId(profile.id),
            backendUserId: profile.id,
            userName: profile.displayName ?? profile.handle,
            userProfileImageUrl: profile.profileImageUrl,
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

    func searchMessages(query: String, limit: Int = 20, cursor: String?) async throws -> MessageSearchPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var endpoint = "/v1/messages/search?query=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)"
        let resolvedLimit = min(max(limit, 1), 50)
        endpoint += "&limit=\(resolvedLimit)"
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }

        let response: MessageSearchResponseDTO = try await apiClient.get(endpoint)
        let items = response.items.compactMap { dto -> MessageSearchHit? in
            let type = MessageSearchHitType(rawValue: dto.type)
            switch type {
            case .conversation:
                guard let conversationId = dto.conversationId,
                      let profile = dto.otherUserProfile
                else { return nil }
                let lastMessage = dto.lastMessage ?? ""
                let lastMessageTimestamp = dto.lastMessageTimestamp ?? Date()
                let conversation = Conversation(
                    id: UUID.fromBackendId(conversationId),
                    backendId: conversationId,
                    userId: UUID.fromBackendId(profile.id),
                    backendUserId: profile.id,
                    userName: profile.displayName ?? profile.handle,
                    userProfileImageUrl: profile.profileImageUrl,
                    lastMessage: lastMessage,
                    lastMessageTimestamp: lastMessageTimestamp,
                    unreadCount: 0,
                    hasTypingIndicator: false,
                    hasSpecialStatus: false,
                    isOnline: false,
                    isGroup: false,
                    memberIds: nil
                )
                let matchedMessage: Message? = dto.matchedMessage.map { matched in
                    Message(
                        id: UUID.fromBackendId(matched.id),
                        backendId: matched.id,
                        content: matched.content,
                        senderId: UUID.fromBackendId(matched.senderId),
                        senderDisplayName: nil,
                        receiverId: nil,
                        conversationBackendId: conversationId,
                        channelBackendId: nil,
                        messageType: .direct,
                        isRead: false,
                        attachments: matched.attachments?.map(MediaAttachment.init(dto:)),
                        createdAt: matched.createdAt
                    )
                }
                let previewText = matchedMessage?.content ?? lastMessage
                let previewTimestamp = matchedMessage?.createdAt ?? dto.lastMessageTimestamp
                return MessageSearchHit(
                    id: "conversation-\(conversationId)",
                    type: .conversation,
                    conversation: conversation,
                    channel: nil,
                    matchedMessage: matchedMessage,
                    previewText: previewText,
                    previewTimestamp: previewTimestamp
                )
            case .channel:
                guard let channelId = dto.channelId,
                      let name = dto.name
                else { return nil }
                let lastMessage = dto.lastMessage ?? ""
                let lastMessageTimestamp = dto.lastMessageTimestamp ?? Date()
                let channel = Channel(
                    id: UUID.fromBackendId(channelId),
                    backendId: channelId,
                    name: name,
                    company: "",
                    memberCount: 0,
                    isPublic: dto.isPublic ?? true,
                    createdAt: Date(),
                    ownerUserId: nil,
                    viewerCanManageMembers: false
                )
                let matchedMessage: Message? = dto.matchedMessage.map { matched in
                    Message(
                        id: UUID.fromBackendId(matched.id),
                        backendId: matched.id,
                        content: matched.content,
                        senderId: UUID.fromBackendId(matched.senderId),
                        senderDisplayName: nil,
                        receiverId: nil,
                        conversationBackendId: nil,
                        channelBackendId: channelId,
                        messageType: .channel,
                        isRead: false,
                        attachments: matched.attachments?.map(MediaAttachment.init(dto:)),
                        createdAt: matched.createdAt
                    )
                }
                let previewText = matchedMessage?.content ?? lastMessage
                let previewTimestamp = matchedMessage?.createdAt ?? dto.lastMessageTimestamp
                return MessageSearchHit(
                    id: "channel-\(channelId)",
                    type: .channel,
                    conversation: nil,
                    channel: channel,
                    matchedMessage: matchedMessage,
                    previewText: previewText,
                    previewTimestamp: previewTimestamp
                )
            case .none:
                return nil
            }
        }
        return MessageSearchPage(items: items, nextCursor: response.nextCursor)
    }
    
    func getChannels(cursor: String?) async throws -> ChannelPage {
        var endpoint = "/v1/channels?limit=50"
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
                createdAt: dto.createdAt ?? Date(),
                ownerUserId: dto.ownerUserId,
                viewerCanManageMembers: dto.viewerCanManageMembers ?? false
            )
        }
        #if DEBUG
        print("Channels fetched: \(channels.count) ids=\(channels.map { $0.backendId })")
        #endif
        return ChannelPage(channels: channels, nextCursor: response.nextCursor)
    }

    func createChannel(name: String, memberUserIds: [Int]) async throws -> Channel {
        let request = CreateChannelRequestDTO(
            name: name,
            memberUserIds: memberUserIds.isEmpty ? nil : memberUserIds
        )
        let dto: ChannelDTO = try await apiClient.post("/v1/channels", body: request)
        return Channel(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            name: dto.name,
            company: "",
            memberCount: dto.memberCount,
            isPublic: dto.isPublic,
            createdAt: dto.createdAt ?? Date(),
            ownerUserId: dto.ownerUserId,
            viewerCanManageMembers: dto.viewerCanManageMembers ?? false
        )
    }

    func getChannelMembers(channelBackendId: Int, cursor: String?) async throws -> ChannelMembersPage {
        var endpoint = "/v1/channels/\(channelBackendId)/members?limit=50"
        if let cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: ChannelMembersResponseDTO = try await apiClient.get(endpoint)
        let members = response.items.map { dto in
            ChannelMember(
                id: UUID.fromBackendId(dto.userId),
                backendUserId: dto.userId,
                handle: dto.handle,
                displayName: dto.displayName,
                profileImageUrl: dto.profileImageUrl,
                companyId: dto.companyId,
                canManageMembers: dto.canManageMembers,
                createdAt: dto.createdAt,
                isOwner: dto.isOwner
            )
        }
        return ChannelMembersPage(members: members, nextCursor: response.nextCursor)
    }

    func addChannelMembers(channelBackendId: Int, userIds: [Int]) async throws -> Int {
        let request = ChannelMembersAddRequestDTO(userIds: userIds)
        let response: ChannelMembersAddResponseDTO = try await apiClient.post(
            "/v1/channels/\(channelBackendId)/members",
            body: request
        )
        return response.addedCount
    }

    func removeChannelMember(channelBackendId: Int, userId: Int) async throws {
        let _: ChannelMemberActionResponseDTO = try await apiClient.delete(
            "/v1/channels/\(channelBackendId)/members/\(userId)",
            expecting: ChannelMemberActionResponseDTO.self
        )
    }

    func updateChannelMemberPermission(channelBackendId: Int, userId: Int, canManageMembers: Bool) async throws {
        let request = ChannelMemberPermissionUpdateDTO(canManageMembers: canManageMembers)
        let _: ChannelMemberActionResponseDTO = try await apiClient.put(
            "/v1/channels/\(channelBackendId)/members/\(userId)",
            body: request
        )
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
        var endpoint = "/v1/message-requests?limit=50"
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
        #if DEBUG
        let summarized = requests.map { "\($0.backendId):\($0.status.rawValue)" }
        print("Message requests fetched: \(requests.count) [\(summarized.joined(separator: ", "))]")
        #endif
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
