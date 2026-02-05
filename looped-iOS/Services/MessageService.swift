import Foundation

class MessageService: MessageServiceProtocol {
    private let apiClient: APIClient
    private let messageMediaService: MessageMediaServiceProtocol
    private let mediaResolveCache: MessageMediaResolvedCache
    private struct EmptyBody: Codable {}
    
    init(
        apiClient: APIClient = APIClient(),
        messageMediaService: MessageMediaServiceProtocol = MessageMediaService(),
        mediaResolveCache: MessageMediaResolvedCache = MessageMediaResolvedCache()
    ) {
        self.apiClient = apiClient
        self.messageMediaService = messageMediaService
        self.mediaResolveCache = mediaResolveCache
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
                isMuted: dto.muted,
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
            isMuted: dto.muted,
            hasTypingIndicator: false,
            hasSpecialStatus: false,
            isOnline: false,
            isGroup: false,
            memberIds: nil
        )
    }

    func updateConversationPreferences(conversationId: Int, muted: Bool) async throws -> Bool {
        struct RequestDTO: Codable { let muted: Bool }
        struct ResponseDTO: Decodable { let muted: Bool? }

        let data = try await apiClient.putData(
            "/v1/conversations/\(conversationId)/preferences",
            body: RequestDTO(muted: muted)
        )

        // Some servers respond 204 No Content for preference updates.
        guard !data.isEmpty else { return muted }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(ResponseDTO.self, from: data)
            if let persisted = response.muted { return persisted }
        } catch {
            #if DEBUG
            let body = String(decoding: data, as: UTF8.self)
            print("Failed decoding conversation preferences response for conversationId=\(conversationId): \(body)")
            #endif
            throw APIError.decodingError(error)
        }

        #if DEBUG
        let body = String(decoding: data, as: UTF8.self)
        print("Conversation preferences response missing `muted` for conversationId=\(conversationId): \(body)")
        #endif
        return muted
    }

    func updateChannelPreferences(channelBackendId: Int, muted: Bool) async throws -> Bool {
        struct RequestDTO: Codable { let muted: Bool }
        struct ResponseDTO: Decodable { let muted: Bool? }

        let data = try await apiClient.putData(
            "/v1/channels/\(channelBackendId)/preferences",
            body: RequestDTO(muted: muted)
        )

        // Some servers respond 204 No Content for preference updates.
        guard !data.isEmpty else { return muted }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let response = try decoder.decode(ResponseDTO.self, from: data)
            if let persisted = response.muted { return persisted }
        } catch {
            #if DEBUG
            let body = String(decoding: data, as: UTF8.self)
            print("Failed decoding channel preferences response for channelBackendId=\(channelBackendId): \(body)")
            #endif
            throw APIError.decodingError(error)
        }

        #if DEBUG
        let body = String(decoding: data, as: UTF8.self)
        print("Channel preferences response missing `muted` for channelBackendId=\(channelBackendId): \(body)")
        #endif
        return muted
    }
    
    func getConversationMessages(conversationId: Int, cursor: String?) async throws -> MessagePage {
        var endpoint = "/v1/conversations/\(conversationId)/messages?limit=50"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: MessageListResponseDTO = try await apiClient.get(endpoint)
        let messages = try await resolveMessages(
            response.items,
            conversationBackendId: conversationId,
            channelBackendId: nil,
            messageType: .direct
        )
        return MessagePage(messages: messages.sorted { $0.createdAt < $1.createdAt }, nextCursor: response.nextCursor)
    }
    
    func sendConversationMessage(conversationId: Int, content: String, attachments: [SendMessageAttachmentDTO]?) async throws -> Message {
        let request = SendMessageRequestDTO(content: content, attachments: attachments)
        let dto: MessageDTO = try await apiClient.post("/v1/conversations/\(conversationId)/messages", body: request)
        return try await resolveMessage(
            dto,
            conversationBackendId: conversationId,
            channelBackendId: nil,
            messageType: .direct
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
        let keysToResolve = response.items.flatMap { dto -> [String] in
            guard let attachments = dto.matchedMessage?.attachments else { return [] }
            return attachmentKeys(from: attachments)
        }
        let resolvedByKey = (try? await resolveAttachmentMap(for: keysToResolve)) ?? [:]
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
                    isMuted: false,
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
                        attachments: resolveAttachments(matched.attachments ?? [], with: resolvedByKey),
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
                let channel = Channel(
                    id: UUID.fromBackendId(channelId),
                    backendId: channelId,
                    name: name,
                    photoUrl: nil,
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
                        attachments: resolveAttachments(matched.attachments ?? [], with: resolvedByKey),
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
        for dto in response.items {
            MutedChatStore.shared.setChannelMuted(dto.muted ?? false, channelId: dto.id)
        }
        let channels = response.items.map { dto in
            Channel(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                name: dto.name,
                photoUrl: dto.photoUrl,
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
        MutedChatStore.shared.setChannelMuted(dto.muted ?? false, channelId: dto.id)
        return Channel(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            name: dto.name,
            photoUrl: dto.photoUrl,
            company: "",
            memberCount: dto.memberCount,
            isPublic: dto.isPublic,
            createdAt: dto.createdAt ?? Date(),
            ownerUserId: dto.ownerUserId,
            viewerCanManageMembers: dto.viewerCanManageMembers ?? false
        )
    }

    func updateChannel(channelBackendId: Int, name: String) async throws {
        struct ChannelUpdateRequestDTO: Codable {
            let name: String?
            let photoMediaAssetId: Int?
        }

        _ = try await apiClient.patchData(
            "/v1/channels/\(channelBackendId)",
            body: ChannelUpdateRequestDTO(name: name, photoMediaAssetId: nil)
        )
    }

    func updateChannelPhoto(channelBackendId: Int, photoMediaAssetId: Int?) async throws -> Channel {
        struct ChannelPhotoUpdateRequestDTO: Encodable {
            let photoMediaAssetId: Int?

            enum CodingKeys: String, CodingKey {
                case photoMediaAssetId
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                if let photoMediaAssetId {
                    try container.encode(photoMediaAssetId, forKey: .photoMediaAssetId)
                } else {
                    try container.encodeNil(forKey: .photoMediaAssetId)
                }
            }
        }

        let dto: ChannelDTO = try await apiClient.patch(
            "/v1/channels/\(channelBackendId)",
            body: ChannelPhotoUpdateRequestDTO(photoMediaAssetId: photoMediaAssetId)
        )

        return Channel(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            name: dto.name,
            photoUrl: dto.photoUrl,
            company: "",
            memberCount: dto.memberCount,
            isPublic: dto.isPublic,
            createdAt: dto.createdAt ?? Date(),
            ownerUserId: dto.ownerUserId,
            viewerCanManageMembers: dto.viewerCanManageMembers ?? false
        )
    }

    func deleteChannel(channelBackendId: Int) async throws {
        try await apiClient.delete("/v1/channels/\(channelBackendId)")
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
        let messages = try await resolveMessages(
            response.items,
            conversationBackendId: nil,
            channelBackendId: channelBackendId,
            messageType: .channel
        )
        return MessagePage(messages: messages.sorted { $0.createdAt < $1.createdAt }, nextCursor: response.nextCursor)
    }
    
    func sendChannelMessage(channelBackendId: Int, content: String, attachments: [SendMessageAttachmentDTO]?) async throws -> Message {
        let request = SendMessageRequestDTO(content: content, attachments: attachments)
        let dto: MessageDTO = try await apiClient.post("/v1/channels/\(channelBackendId)/messages", body: request)
        return try await resolveMessage(
            dto,
            conversationBackendId: nil,
            channelBackendId: channelBackendId,
            messageType: .channel
        )
    }

    func fetchMessageRequests(cursor: String?) async throws -> MessageRequestPage {
        var endpoint = "/v1/message-requests?limit=50"
        if let cursor = cursor, !cursor.isEmpty {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            endpoint += "&cursor=\(encoded)"
        }
        let response: MessageRequestListResponseDTO = try await apiClient.get(endpoint)
        struct RequestPreviewParts {
            let dto: MessageRequestDTO
            let directAttachments: [MediaAttachment]
            let attachmentKeys: [String]
        }

        let parts: [RequestPreviewParts] = response.items.map { dto in
            let preview = dto.preview
            let raw = preview?.attachments ?? []

            let directAttachments = raw.compactMap { attachment -> MediaAttachment? in
                guard URL(string: attachment.url)?.scheme != nil else { return nil }
                return MediaAttachment(dto: attachment)
            }
            let keys = raw.compactMap { attachment -> String? in
                guard URL(string: attachment.url)?.scheme == nil else { return nil }
                return attachment.url
            }
            return RequestPreviewParts(dto: dto, directAttachments: directAttachments, attachmentKeys: keys)
        }

        let keysToResolve = parts.flatMap(\.attachmentKeys)
        let resolvedByKey = (try? await resolveAttachmentMap(for: keysToResolve)) ?? [:]

        let requests = parts.map { part in
            let dto = part.dto
            let preview = dto.preview
            let senderName = dto.senderProfile?.displayName ?? dto.senderProfile?.handle
            let resolvedFromKeys = resolveAttachments(part.attachmentKeys, with: resolvedByKey) ?? []
            let previewAttachments = part.directAttachments + resolvedFromKeys
            return MessageRequest(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                senderBackendId: dto.senderId,
                senderName: senderName,
                senderHandle: dto.senderProfile?.handle,
                senderProfileImageUrl: dto.senderProfile?.profileImageUrl,
                previewText: preview?.content ?? "",
                previewAttachments: previewAttachments,
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

private extension MessageService {
    func resolveMessage(
        _ dto: MessageDTO,
        conversationBackendId: Int?,
        channelBackendId: Int?,
        messageType: MessageType
    ) async throws -> Message {
        let attachmentDtos = dto.attachments ?? []
        let keysToResolve = attachmentKeys(from: attachmentDtos)
        let byKey = try await resolveAttachmentMap(for: keysToResolve)
        let resolvedAttachments = resolveAttachments(attachmentDtos, with: byKey)
        return Message(
            id: UUID.fromBackendId(dto.id),
            backendId: dto.id,
            content: dto.content,
            senderId: UUID.fromBackendId(dto.senderId),
            senderDisplayName: nil,
            receiverId: nil,
            conversationBackendId: conversationBackendId,
            channelBackendId: channelBackendId,
            messageType: messageType,
            isRead: false,
            attachments: resolvedAttachments,
            createdAt: dto.createdAt
        )
    }

    func resolveMessages(
        _ dtos: [MessageDTO],
        conversationBackendId: Int?,
        channelBackendId: Int?,
        messageType: MessageType
    ) async throws -> [Message] {
        let allKeys = dtos.flatMap { attachmentKeys(from: $0.attachments ?? []) }
        let byKey = try await resolveAttachmentMap(for: allKeys)

        return dtos.map { dto in
            let resolvedAttachments = resolveAttachments(dto.attachments ?? [], with: byKey)
            return Message(
                id: UUID.fromBackendId(dto.id),
                backendId: dto.id,
                content: dto.content,
                senderId: UUID.fromBackendId(dto.senderId),
                senderDisplayName: nil,
                receiverId: nil,
                conversationBackendId: conversationBackendId,
                channelBackendId: channelBackendId,
                messageType: messageType,
                isRead: false,
                attachments: resolvedAttachments,
                createdAt: dto.createdAt
            )
        }
    }

    func attachmentKeys(from attachments: [MediaAttachmentDTO]) -> [String] {
        var keys: [String] = []
        keys.reserveCapacity(attachments.count * 2)
        for attachment in attachments {
            let candidates = [attachment.url, attachment.thumbnailUrl].compactMap { $0 }
            for candidate in candidates {
                let raw = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else { continue }
                guard URL(string: raw)?.scheme == nil else { continue }
                guard raw.hasPrefix("dm/") else { continue }
                keys.append(raw)
            }
        }
        return keys
    }

    func resolveAttachmentMap(for keys: [String]) async throws -> [String: MessageMediaResolvedItem] {
        let deduped = Array(Set(keys)).sorted()
        guard !deduped.isEmpty else { return [:] }
        let cached = await mediaResolveCache.getValid(for: deduped)
        let missing = deduped.filter { cached[$0] == nil }
        guard !missing.isEmpty else { return cached }

        let fetched = try await messageMediaService.resolve(keys: missing)
        await mediaResolveCache.store(fetched)

        var combined = cached
        for item in fetched {
            combined[item.key] = item
        }
        return combined
    }

    func resolveAttachments(_ attachments: [MediaAttachmentDTO], with byKey: [String: MessageMediaResolvedItem]) -> [MediaAttachment]? {
        guard !attachments.isEmpty else { return nil }
        var resolved: [MediaAttachment] = []
        resolved.reserveCapacity(attachments.count)

        for attachment in attachments {
            let rawUrl = attachment.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawUrl.isEmpty else { continue }

            let urlKey: String?
            let resolvedUrl: String
            let resolvedMimeType: String?
            if URL(string: rawUrl)?.scheme == nil, rawUrl.hasPrefix("dm/") {
                urlKey = rawUrl
                guard let item = byKey[rawUrl], !item.downloadUrl.isEmpty else { continue }
                resolvedUrl = item.downloadUrl
                resolvedMimeType = item.mimeType?.lowercased()
            } else {
                urlKey = nil
                resolvedUrl = rawUrl
                resolvedMimeType = nil
            }

            let rawThumb = attachment.thumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            let thumbKey: String?
            let resolvedThumbUrl: String?
            if let rawThumb, !rawThumb.isEmpty {
                if URL(string: rawThumb)?.scheme == nil, rawThumb.hasPrefix("dm/") {
                    thumbKey = rawThumb
                    if let item = byKey[rawThumb], !item.downloadUrl.isEmpty {
                        resolvedThumbUrl = item.downloadUrl
                    } else {
                        resolvedThumbUrl = nil
                    }
                } else {
                    thumbKey = nil
                    resolvedThumbUrl = rawThumb
                }
            } else {
                thumbKey = nil
                resolvedThumbUrl = nil
            }

            let trimmedType = attachment.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let resolvedType: MediaType
            if let trimmedType, !trimmedType.isEmpty {
                if let type = MediaType(rawValue: trimmedType) {
                    resolvedType = type
                } else if trimmedType.hasPrefix("video") || trimmedType.contains("video/") {
                    resolvedType = .video
                } else if trimmedType.hasPrefix("image") || trimmedType.contains("image/") {
                    resolvedType = .image
                } else {
                    let isVideo = resolvedMimeType?.hasPrefix("video/") == true
                        || resolvedUrl.lowercased().contains(".mp4")
                        || attachment.durationSeconds != nil
                    resolvedType = isVideo ? .video : .image
                }
            } else {
                let isVideo = resolvedMimeType?.hasPrefix("video/") == true
                    || resolvedUrl.lowercased().contains(".mp4")
                    || attachment.durationSeconds != nil
                resolvedType = isVideo ? .video : .image
            }

            #if DEBUG
            if resolvedType == .video {
                let idForLog = urlKey ?? resolvedUrl
                let thumbStatus = resolvedThumbUrl == nil ? "missing" : "present"
                print("LOOPED_MESSAGE_MEDIA resolved video id=\(idForLog) thumbnail=\(thumbStatus)")
            }
            #endif

            resolved.append(
                MediaAttachment(
                    id: urlKey ?? resolvedUrl,
                    type: resolvedType,
                    url: resolvedUrl,
                    thumbnailUrl: resolvedThumbUrl,
                    thumbnailKey: thumbKey,
                    width: attachment.width,
                    height: attachment.height,
                    duration: attachment.durationSeconds,
                    fileSize: attachment.sizeBytes
                )
            )
        }

        return resolved.isEmpty ? nil : resolved
    }

    func resolveAttachments(_ keys: [String], with byKey: [String: MessageMediaResolvedItem]) -> [MediaAttachment]? {
        let attachments = keys.compactMap { key -> MediaAttachment? in
            let raw = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return nil }
            guard let item = byKey[raw], !item.downloadUrl.isEmpty else { return nil }
            let mime = item.mimeType?.lowercased()
            let isVideo = mime?.hasPrefix("video/") == true || item.downloadUrl.lowercased().contains(".mp4")
            return MediaAttachment(id: raw, type: isVideo ? .video : .image, url: item.downloadUrl)
        }
        return attachments.isEmpty ? nil : attachments
    }
}
