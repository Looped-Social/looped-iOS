import Foundation
import Combine
import SwiftUI
import UIKit
import AVFoundation

private enum ChatConversationPreviewUpdate {
    static let name = Foundation.Notification.Name("ChatConversationPreviewUpdate")
    static let conversationBackendIdKey = "conversationBackendId"
    static let previewTextKey = "previewText"
    static let timestampKey = "timestamp"
}

private enum ChatConversationReadUpdate {
    static let name = Foundation.Notification.Name("ChatConversationReadUpdate")
    static let conversationBackendIdKey = "conversationBackendId"
}

private enum ChatChannelUpdate {
    static let name = Foundation.Notification.Name("ChatChannelUpdated")
    static let channelBackendIdKey = "channelBackendId"
    static let nameKey = "name"
    static let photoUrlKey = "photoUrl"
}

private enum ChatChannelDelete {
    static let name = Foundation.Notification.Name("ChatChannelDeleted")
    static let channelBackendIdKey = "channelBackendId"
}

@MainActor
class MessagesViewModel: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var conversations: [Conversation] = []
    @Published var messageRequests: [MessageRequest] = []
    @Published var isLoading = false
    @Published var isLoadingRequests = false
    @Published var isLoadingChannels = false
    @Published var isSearching = false
    @Published var searchResults: [MessageSearchHit] = []
    @Published var searchErrorMessage: String?
    @Published var processingRequestIds: Set<Int> = []
    @Published var errorMessage: String?
    @Published var channelErrorMessage: String?

    private let messageService: MessageServiceProtocol
    private let userService: UserServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var senderCache: [Int: RequestSenderProfile] = [:]
    private var searchTask: Task<Void, Never>?

    init(
        messageService: MessageServiceProtocol = MessageService(),
        userService: UserServiceProtocol = UserService()
    ) {
        self.messageService = messageService
        self.userService = userService

        NotificationCenter.default.publisher(for: ChatConversationPreviewUpdate.name)
            .compactMap { notification -> (Int, String, Date)? in
                guard let backendId = notification.userInfo?[ChatConversationPreviewUpdate.conversationBackendIdKey] as? Int else { return nil }
                let previewText = notification.userInfo?[ChatConversationPreviewUpdate.previewTextKey] as? String ?? ""
                guard let timestamp = notification.userInfo?[ChatConversationPreviewUpdate.timestampKey] as? Date else { return nil }
                return (backendId, previewText, timestamp)
            }
            .sink { [weak self] backendId, previewText, timestamp in
                Task { @MainActor in
                    self?.applyConversationPreviewUpdate(
                        conversationBackendId: backendId,
                        previewText: previewText,
                        timestamp: timestamp
                    )
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: ChatConversationReadUpdate.name)
            .compactMap { notification -> Int? in
                notification.userInfo?[ChatConversationReadUpdate.conversationBackendIdKey] as? Int
            }
            .sink { [weak self] backendId in
                Task { @MainActor in
                    self?.applyConversationReadUpdate(conversationBackendId: backendId)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: ChatChannelUpdate.name)
            .compactMap { notification -> (Int, String?, String??)? in
                guard let backendId = notification.userInfo?[ChatChannelUpdate.channelBackendIdKey] as? Int else { return nil }
                let name: String?
                if let rawName = notification.userInfo?[ChatChannelUpdate.nameKey] as? String {
                    let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                    name = trimmed.isEmpty ? nil : trimmed
                } else {
                    name = nil
                }

                let photoUrlUpdate: String??
                if let rawPhotoValue = notification.userInfo?[ChatChannelUpdate.photoUrlKey] {
                    if rawPhotoValue is NSNull {
                        photoUrlUpdate = .some(nil)
                    } else if let rawPhotoUrl = rawPhotoValue as? String {
                        photoUrlUpdate = .some(rawPhotoUrl)
                    } else {
                        photoUrlUpdate = nil
                    }
                } else {
                    photoUrlUpdate = nil
                }

                return (backendId, name, photoUrlUpdate)
            }
            .sink { [weak self] backendId, name, photoUrlUpdate in
                Task { @MainActor in
                    self?.applyChannelUpdate(channelBackendId: backendId, name: name, photoUrlUpdate: photoUrlUpdate)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: ChatChannelDelete.name)
            .compactMap { notification -> Int? in
                notification.userInfo?[ChatChannelDelete.channelBackendIdKey] as? Int
            }
            .sink { [weak self] backendId in
                Task { @MainActor in
                    self?.channels.removeAll { $0.backendId == backendId }
                }
            }
            .store(in: &cancellables)
    }

    private func applyConversationPreviewUpdate(conversationBackendId: Int, previewText: String, timestamp: Date) {
        guard let existingIndex = conversations.firstIndex(where: { $0.backendId == conversationBackendId }) else { return }
        let existing = conversations[existingIndex]
        let updated = Conversation(
            id: existing.id,
            backendId: existing.backendId,
            userId: existing.userId,
            backendUserId: existing.backendUserId,
            userName: existing.userName,
            userProfileImageUrl: existing.userProfileImageUrl,
            lastMessage: previewText,
            lastMessageTimestamp: timestamp,
            unreadCount: existing.unreadCount,
            isMuted: existing.isMuted,
            hasTypingIndicator: existing.hasTypingIndicator,
            hasSpecialStatus: existing.hasSpecialStatus,
            isOnline: existing.isOnline,
            isGroup: existing.isGroup,
            memberIds: existing.memberIds
        )
        conversations.remove(at: existingIndex)
        conversations.insert(updated, at: 0)
    }

    private func applyConversationReadUpdate(conversationBackendId: Int) {
        guard let existingIndex = conversations.firstIndex(where: { $0.backendId == conversationBackendId }) else { return }
        let existing = conversations[existingIndex]
        guard existing.unreadCount != 0 else { return }
        let updated = Conversation(
            id: existing.id,
            backendId: existing.backendId,
            userId: existing.userId,
            backendUserId: existing.backendUserId,
            userName: existing.userName,
            userProfileImageUrl: existing.userProfileImageUrl,
            lastMessage: existing.lastMessage,
            lastMessageTimestamp: existing.lastMessageTimestamp,
            unreadCount: 0,
            isMuted: existing.isMuted,
            hasTypingIndicator: existing.hasTypingIndicator,
            hasSpecialStatus: existing.hasSpecialStatus,
            isOnline: existing.isOnline,
            isGroup: existing.isGroup,
            memberIds: existing.memberIds
        )
        conversations[existingIndex] = updated
    }

    private func applyChannelUpdate(channelBackendId: Int, name: String?, photoUrlUpdate: String??) {
        guard let existingIndex = channels.firstIndex(where: { $0.backendId == channelBackendId }) else { return }
        let existing = channels[existingIndex]
        let updatedName = name ?? existing.name
        let updatedPhotoUrl = photoUrlUpdate ?? existing.photoUrl

        let updated = Channel(
            id: existing.id,
            backendId: existing.backendId,
            name: updatedName,
            photoUrl: updatedPhotoUrl,
            company: existing.company,
            memberCount: existing.memberCount,
            isPublic: existing.isPublic,
            createdAt: existing.createdAt,
            ownerUserId: existing.ownerUserId,
            viewerCanManageMembers: existing.viewerCanManageMembers
        )
        channels[existingIndex] = updated
    }

    func loadChannels() async {
        isLoadingChannels = true
        channelErrorMessage = nil

        do {
            let page = try await messageService.getChannels(cursor: nil)
            channels = page.channels
        } catch {
            channelErrorMessage = error.localizedDescription
        }

        isLoadingChannels = false
    }

    func loadConversations() async {
        isLoading = true
        errorMessage = nil

        do {
            let page = try await messageService.listConversations(cursor: nil)
            conversations = page.conversations
            syncMutedConversationStore(with: conversations)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadInbox() async {
        isLoading = true
        isLoadingChannels = true
        errorMessage = nil
        channelErrorMessage = nil

        defer {
            isLoading = false
            isLoadingChannels = false
        }

        do {
            let page = try await messageService.listConversations(cursor: nil)
            conversations = page.conversations
            syncMutedConversationStore(with: conversations)
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            let page = try await messageService.fetchMessageRequests(cursor: nil)
            messageRequests = page.requests.filter { $0.status == .pending }
            await hydrateSenderProfiles(for: messageRequests)
        } catch {
            if errorMessage == nil || errorMessage?.isEmpty == true {
                errorMessage = error.localizedDescription
            }
        }

        do {
            let page = try await messageService.getChannels(cursor: nil)
            channels = page.channels
        } catch {
            channelErrorMessage = error.localizedDescription
        }
    }

    private func syncMutedConversationStore(with conversations: [Conversation]) {
        for conversation in conversations {
            MutedChatStore.shared.setConversationMuted(conversation.isMuted, conversationId: conversation.backendId)
        }
    }

    func loadMessageRequests() async {
        isLoadingRequests = true
        errorMessage = nil

        do {
            let page = try await messageService.fetchMessageRequests(cursor: nil)
            messageRequests = page.requests.filter { $0.status == .pending }
            await hydrateSenderProfiles(for: messageRequests)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingRequests = false
    }

    @discardableResult
    func approveMessageRequest(_ request: MessageRequest) async -> Conversation? {
        guard !processingRequestIds.contains(request.backendId) else { return nil }
        processingRequestIds.insert(request.backendId)
        defer { processingRequestIds.remove(request.backendId) }

        do {
            try await messageService.approveMessageRequest(requestId: request.backendId)
            messageRequests.removeAll { $0.backendId == request.backendId }

            if request.isGroup {
                await loadChannels()
                return nil
            }

            if let senderBackendId = request.senderBackendId {
                do {
                    let conversation = try await messageService.startConversation(with: senderBackendId)
                    upsertConversationToTop(conversation)
                    return conversation
                } catch {
                    errorMessage = error.localizedDescription
                }
            }

            await loadConversations()
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    func rejectMessageRequest(_ request: MessageRequest) async {
        guard !processingRequestIds.contains(request.backendId) else { return }
        processingRequestIds.insert(request.backendId)
        defer { processingRequestIds.remove(request.backendId) }

        do {
            try await messageService.rejectMessageRequest(requestId: request.backendId)
            messageRequests.removeAll { $0.backendId == request.backendId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshConversations() async {
        await loadConversations()
    }

    func refreshInbox() async {
        await loadInbox()
    }

    func clearSearch() {
        searchTask?.cancel()
        isSearching = false
        searchResults = []
        searchErrorMessage = nil
    }

    func searchMessages(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            clearSearch()
            return
        }

        guard !AnonService.shared.isAnonymousEnabled else {
            clearSearch()
            searchErrorMessage = "Message search isn’t available in anonymous mode."
            return
        }

        isSearching = true
        searchErrorMessage = nil

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            do {
                let page = try await messageService.searchMessages(query: trimmed, limit: 20, cursor: nil)
                await MainActor.run {
                    self.searchResults = page.items
                    self.isSearching = false
                    self.searchErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.searchResults = []
                    self.isSearching = false
                    self.searchErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func upsertConversationToTop(_ conversation: Conversation) {
        conversations.removeAll { $0.backendId == conversation.backendId }
        conversations.insert(conversation, at: 0)
    }

    private func hydrateSenderProfiles(for requests: [MessageRequest]) async {
        let idsToFetch = Set(requests.compactMap { $0.senderBackendId })
            .subtracting(senderCache.keys)
        guard !idsToFetch.isEmpty else { return }

        var fetchedProfiles: [Int: RequestSenderProfile] = [:]
        await withTaskGroup(of: (Int, RequestSenderProfile)?.self) { group in
            for backendId in idsToFetch {
                group.addTask { [userService] in
                    do {
                        let user = try await userService.getUser(by: backendId)
                        let name = user.displayName ?? user.username ?? user.handle
                        return (backendId, RequestSenderProfile(name: name, profileImageUrl: user.profileImageURL))
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let (id, profile) = result {
                    fetchedProfiles[id] = profile
                }
            }
        }

        if fetchedProfiles.isEmpty { return }
        senderCache.merge(fetchedProfiles) { _, new in new }
        messageRequests = messageRequests.map { request in
            guard let backendId = request.senderBackendId,
                  let profile = senderCache[backendId],
                  request.senderName == nil
            else {
                return request
            }
            return request.updatingSender(name: profile.name, profileImageUrl: profile.profileImageUrl)
        }
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var toastMessage: ToastMessage?
    @Published var messageRequestState: MessageRequestBlockState?
    @Published private var channelMembersByUserId: [UUID: ChannelMember] = [:]
    
    private let messageService: MessageServiceProtocol
    private let messageMediaService: MessageMediaServiceProtocol
    private let webSocketService: WebSocketServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var conversationBackendId: Int?
    private var channelBackendId: Int?
    private var nextCursor: String?
    private var pollingTask: Task<Void, Never>?
    private let pollingIntervalNanoseconds: UInt64 = 2_500_000_000
    private var loadedMemberChannelBackendId: Int?
    private var isLoadingChannelMembers = false

    init(
        messageService: MessageServiceProtocol = MessageService(),
        messageMediaService: MessageMediaServiceProtocol = MessageMediaService(),
        webSocketService: WebSocketServiceProtocol = WebSocketService()
    ) {
        self.messageService = messageService
        self.messageMediaService = messageMediaService
        self.webSocketService = webSocketService
        setupWebSocketListeners()
    }

    func senderAvatarURL(for message: Message) -> String? {
        channelMembersByUserId[message.senderId]?.profileImageUrl
    }
    
    func configure(conversationBackendId: Int? = nil, channelBackendId: Int? = nil) {
        self.conversationBackendId = conversationBackendId
        self.channelBackendId = channelBackendId
    }

    func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: pollingIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                await pollOnce()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func loadMessages(for channel: Channel) async {
        isLoading = true
        errorMessage = nil
        messageRequestState = nil

        do {
            let page = try await messageService.getChannelMessages(channelBackendId: channel.backendId, cursor: nil)
            messages = page.messages.map(hydratedMessage)
            nextCursor = page.nextCursor
            Task { await loadChannelMembers(channelBackendId: channel.backendId) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadChannelMessages(channelBackendId: Int) async {
        isLoading = true
        errorMessage = nil
        messageRequestState = nil

        do {
            let page = try await messageService.getChannelMessages(channelBackendId: channelBackendId, cursor: nil)
            messages = page.messages.map(hydratedMessage)
            nextCursor = page.nextCursor
            Task { await loadChannelMembers(channelBackendId: channelBackendId) }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadDirectMessages() async {
        isLoading = true
        errorMessage = nil
        messageRequestState = nil

        guard let conversationBackendId else {
            errorMessage = "Direct messages require a conversation ID."
            isLoading = false
            return
        }

        do {
            let page = try await messageService.getConversationMessages(conversationId: conversationBackendId, cursor: nil)
            messages = page.messages
            nextCursor = page.nextCursor
        } catch {
            handleDirectMessageError(error)
        }

        isLoading = false
    }

    func sendMessage(_ content: String, media: [LocalMediaItem], to channel: Channel) async -> Bool {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        defer { isSending = false }

        do {
            let attachments = try await uploadAttachments(from: media)
            let resolvedContent = normalizedMessageContent(trimmedContent, attachments: attachments)
            guard let resolvedContent else {
                let message = "Type a message or attach media."
                errorMessage = message
                toastMessage = ToastMessage(text: message, kind: .error)
                return false
            }
            let message = try await messageService.sendChannelMessage(
                channelBackendId: channel.backendId,
                content: resolvedContent,
                attachments: attachments.isEmpty ? nil : attachments
            )
            messages.append(hydratedMessage(message))
            return true
        } catch {
            let resolved = userFacingErrorMessage(for: error)
            errorMessage = resolved
            toastMessage = ToastMessage(text: resolved, kind: .error)
            return false
        }
    }

    func sendChannelMessage(channelBackendId: Int, content: String, media: [LocalMediaItem]) async -> Bool {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        defer { isSending = false }

        do {
            let attachments = try await uploadAttachments(from: media)
            let resolvedContent = normalizedMessageContent(trimmedContent, attachments: attachments)
            guard let resolvedContent else {
                let message = "Type a message or attach media."
                errorMessage = message
                toastMessage = ToastMessage(text: message, kind: .error)
                return false
            }
            let message = try await messageService.sendChannelMessage(
                channelBackendId: channelBackendId,
                content: resolvedContent,
                attachments: attachments.isEmpty ? nil : attachments
            )
            messages.append(hydratedMessage(message))
            return true
        } catch {
            let resolved = userFacingErrorMessage(for: error)
            errorMessage = resolved
            toastMessage = ToastMessage(text: resolved, kind: .error)
            return false
        }
    }

    func sendDirectMessage(_ content: String, media: [LocalMediaItem]) async -> Bool {
        guard let conversationBackendId else {
            errorMessage = "Direct messages require a conversation ID."
            toastMessage = ToastMessage(text: errorMessage ?? "Couldn't send message", kind: .error)
            return false
        }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        defer { isSending = false }

        do {
            let attachments = try await uploadAttachments(from: media)
            let resolvedContent = normalizedMessageContent(trimmedContent, attachments: attachments)
            guard let resolvedContent else {
                let message = "Type a message or attach media."
                errorMessage = message
                toastMessage = ToastMessage(text: message, kind: .error)
                return false
            }
            let message = try await messageService.sendConversationMessage(
                conversationId: conversationBackendId,
                content: resolvedContent,
                attachments: attachments.isEmpty ? nil : attachments
            )
            messages.append(message)
            publishConversationPreviewUpdate(for: message)
            return true
        } catch {
            handleDirectMessageError(error)
            toastMessage = ToastMessage(text: errorMessage ?? userFacingErrorMessage(for: error), kind: .error)
            return false
        }
    }

    private func handleDirectMessageError(_ error: Error) {
        if case let APIError.apiError(_, apiError, _) = error {
            if apiError == "message_request_pending" {
                messageRequestState = .pending
                errorMessage = "Message request pending approval."
                return
            }
            if apiError == "message_request_rejected" {
                messageRequestState = .rejected
                errorMessage = "Message request rejected."
                return
            }
        }
        errorMessage = userFacingErrorMessage(for: error)
    }

    private func normalizedMessageContent(_ trimmedContent: String, attachments: [SendMessageAttachmentDTO]) -> String? {
        if !trimmedContent.isEmpty { return trimmedContent }
        if !attachments.isEmpty {
            // Some backends reject empty strings; send an invisible character to represent attachment-only messages.
            return "\u{200B}"
        }
        return nil
    }

    private func userFacingErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .apiError(_, let code, let message):
                if code == "unsupported_content_type" {
                    return "That file type isn’t supported for messages yet."
                }
                if code == "size_exceeds_limit" {
                    return "That file is too large to send."
                }
                if code == "message_media_bucket_not_configured" {
                    return "Media sending isn’t available right now. Try again later."
                }
                if code == "anonymous_not_allowed" {
                    return "Anonymous users can’t send attachments."
                }
                if code == "invalid_attachments" {
                    return "We couldn’t attach that media. Please try again."
                }
                return message ?? code
            default:
                return apiError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private func uploadAttachments(from media: [LocalMediaItem]) async throws -> [SendMessageAttachmentDTO] {
        guard !media.isEmpty else { return [] }
        var attachments: [SendMessageAttachmentDTO] = []
        attachments.reserveCapacity(media.count)

        for item in media {
            switch item.type {
            case .image:
                guard let image = item.image else { throw ChatMediaUploadError.unreadableImage }
                guard let payload = makeUploadPayload(from: image) else { throw ChatMediaUploadError.unreadableImage }
                let key = try await messageMediaService.uploadImage(data: payload.data, mimeType: payload.mimeType)
                guard key.hasPrefix("dm/") else { throw ChatMediaUploadError.invalidAttachmentKey }
                attachments.append(
                    SendMessageAttachmentDTO(
                        url: key,
                        type: "image",
                        width: payload.width,
                        height: payload.height,
                        durationSeconds: nil,
                        sizeBytes: Int64(payload.data.count),
                        thumbnailUrl: nil
                    )
                )
            case .video:
                guard let url = item.videoURL else { throw ChatMediaUploadError.unreadableVideo }
                let mp4Url = try await VideoTranscoder.ensureMP4(at: url)
                defer {
                    TemporaryMediaFile.deleteIfOwned(mp4Url)
                    TemporaryMediaFile.deleteIfOwned(url)
                }
                let metadata = videoUploadMetadata(url: mp4Url)

                var thumbnailKey: String?
                if let thumbnailImage = item.image ?? makeVideoThumbnail(url: mp4Url) {
                    let preparedThumbnail = opaqueThumbnailImage(thumbnailImage, background: .white)
                    if let payload = makeUploadPayload(from: preparedThumbnail) {
                    do {
                        let key = try await messageMediaService.uploadImage(data: payload.data, mimeType: payload.mimeType)
                        if key.hasPrefix("dm/") {
                            thumbnailKey = key
                        }
                    } catch {
                        #if DEBUG
                        print("LOOPED_MESSAGE_MEDIA thumbnail upload failed: \(error)")
                        #endif
                        thumbnailKey = nil
                    }
                    }
                }

                let videoKey = try await messageMediaService.uploadVideo(fileURL: mp4Url, mimeType: "video/mp4")
                guard videoKey.hasPrefix("dm/") else { throw ChatMediaUploadError.invalidAttachmentKey }
                #if DEBUG
                print("LOOPED_MESSAGE_MEDIA upload videoKey=\(videoKey) thumbnailKey=\(thumbnailKey ?? "nil") duration=\(metadata.durationSeconds)s size=\(metadata.sizeBytes)")
                #endif
                attachments.append(
                    SendMessageAttachmentDTO(
                        url: videoKey,
                        type: "video",
                        width: metadata.width,
                        height: metadata.height,
                        durationSeconds: metadata.durationSeconds,
                        sizeBytes: metadata.sizeBytes,
                        thumbnailUrl: thumbnailKey
                    )
                )
            case .gif:
                throw ChatMediaUploadError.unsupportedMedia
            }
        }

        return attachments
    }

    private func videoUploadMetadata(url: URL) -> (width: Int, height: Int, durationSeconds: Int, sizeBytes: Int64) {
        let asset = AVAsset(url: url)
        let duration = Int((asset.duration.seconds.isFinite ? asset.duration.seconds : 0).rounded())
        var width = 0
        var height = 0
        if let track = asset.tracks(withMediaType: .video).first {
            let transformed = track.naturalSize.applying(track.preferredTransform)
            width = Int(abs(transformed.width).rounded())
            height = Int(abs(transformed.height).rounded())
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        return (
            width: max(width, 0),
            height: max(height, 0),
            durationSeconds: max(duration, 0),
            sizeBytes: max(size, 0)
        )
    }

    private func makeVideoThumbnail(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    private func makeUploadPayload(from image: UIImage) -> ChatImageUploadPayload? {
        guard let output = ImageUploadTranscoder.makeUploadPayload(from: image) else { return nil }
        return ChatImageUploadPayload(data: output.data, mimeType: output.mimeType, width: output.width, height: output.height)
    }

    private func opaqueThumbnailImage(_ image: UIImage, background: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
    
    private func setupWebSocketListeners() {
        webSocketService.messageReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                if self.messages.contains(where: { $0.backendId == message.backendId }) == false {
                    let hydrated = self.hydratedMessage(message)
                    self.messages.append(hydrated)
                    self.publishConversationPreviewUpdate(for: hydrated)
                }
            }
            .store(in: &cancellables)
    }

    private func pollOnce() async {
        guard !isLoading else { return }
        guard messageRequestState == nil else { return }
        if conversationBackendId == nil && channelBackendId == nil { return }

        do {
            if let channelBackendId {
                let page = try await messageService.getChannelMessages(channelBackendId: channelBackendId, cursor: nextCursor)
                mergePolledMessages(page.messages.map(hydratedMessage))
                if let cursor = page.nextCursor { nextCursor = cursor }
                return
            }
            if let conversationBackendId {
                let page = try await messageService.getConversationMessages(conversationId: conversationBackendId, cursor: nextCursor)
                mergePolledMessages(page.messages)
                if let cursor = page.nextCursor { nextCursor = cursor }
            }
        } catch {
            // Back off by effectively stopping polling on auth/permission issues.
            if case let APIError.apiError(_, code, _) = error, code == "message_request_pending" || code == "message_request_rejected" {
                messageRequestState = code == "message_request_pending" ? .pending : .rejected
                stopPolling()
                return
            }
            // Keep polling on transient network errors.
        }
    }

    private func mergePolledMessages(_ incoming: [Message]) {
        guard !incoming.isEmpty else { return }
        var seen = Set(messages.map(\.backendId))
        var appended: [Message] = []
        appended.reserveCapacity(incoming.count)

        for message in incoming where !seen.contains(message.backendId) {
            seen.insert(message.backendId)
            appended.append(message)
        }
        guard !appended.isEmpty else { return }
        messages.append(contentsOf: appended)
        if let latest = appended.max(by: { $0.createdAt < $1.createdAt }) {
            publishConversationPreviewUpdate(for: latest)
        }
    }

    private func publishConversationPreviewUpdate(for message: Message) {
        guard message.messageType == .direct else { return }
        guard let conversationBackendId = message.conversationBackendId else { return }

        let previewText = conversationPreviewText(for: message)
        NotificationCenter.default.post(
            name: ChatConversationPreviewUpdate.name,
            object: nil,
            userInfo: [
                ChatConversationPreviewUpdate.conversationBackendIdKey: conversationBackendId,
                ChatConversationPreviewUpdate.previewTextKey: previewText,
                ChatConversationPreviewUpdate.timestampKey: message.createdAt
            ]
        )
    }

    private func conversationPreviewText(for message: Message) -> String {
        let trimmed = message.normalizedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }

        guard let attachments = message.attachments, !attachments.isEmpty else { return "" }
        let imagesCount = attachments.filter { $0.type == .image }.count
        let videosCount = attachments.filter { $0.type == .video }.count

        if imagesCount > 0 && videosCount == 0 {
            return imagesCount == 1 ? "Photo" : "\(imagesCount) Photos"
        }
        if videosCount > 0 && imagesCount == 0 {
            return videosCount == 1 ? "Video" : "\(videosCount) Videos"
        }
        if imagesCount > 0 && videosCount > 0 {
            return "Media"
        }
        return "Attachment"
    }

    private func loadChannelMembers(channelBackendId: Int) async {
        guard loadedMemberChannelBackendId != channelBackendId || channelMembersByUserId.isEmpty else { return }
        guard !isLoadingChannelMembers else { return }
        isLoadingChannelMembers = true
        defer { isLoadingChannelMembers = false }

        do {
            let page = try await messageService.getChannelMembers(channelBackendId: channelBackendId, cursor: nil)
            loadedMemberChannelBackendId = channelBackendId
            channelMembersByUserId = Dictionary(uniqueKeysWithValues: page.members.map { ($0.id, $0) })
            hydrateMessagesFromMembers()
        } catch {
            // Best-effort only; group chat can still function without member metadata.
        }
    }

    private func hydrateMessagesFromMembers() {
        messages = messages.map(hydratedMessage)
    }

    private func hydratedMessage(_ message: Message) -> Message {
        guard message.messageType == .channel else { return message }
        guard let member = channelMembersByUserId[message.senderId] else { return message }
        let resolvedName = (member.displayName ?? member.handle).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedName.isEmpty else { return message }
        guard message.senderDisplayName != resolvedName else { return message }

        return Message(
            id: message.id,
            backendId: message.backendId,
            content: message.content,
            senderId: message.senderId,
            senderDisplayName: resolvedName,
            receiverId: message.receiverId,
            conversationBackendId: message.conversationBackendId,
            channelBackendId: message.channelBackendId,
            messageType: message.messageType,
            isRead: message.isRead,
            attachments: message.attachments,
            createdAt: message.createdAt
        )
    }
}

private struct ChatImageUploadPayload {
    let data: Data
    let mimeType: String
    let width: Int
    let height: Int
}

private enum ChatMediaUploadError: LocalizedError {
    case unsupportedMedia
    case unreadableImage
    case unreadableVideo
    case invalidAttachmentKey

    var errorDescription: String? {
        switch self {
        case .unsupportedMedia:
            return "That media type isn't supported in messages yet."
        case .unreadableImage:
            return "We couldn't read that image. Try another one."
        case .unreadableVideo:
            return "We couldn't read that video. Try another one."
        case .invalidAttachmentKey:
            return "We couldn't attach that media. Please try again."
        }
    }
}

private struct RequestSenderProfile {
    let name: String
    let profileImageUrl: String?
}

enum MessageRequestBlockState {
    case pending
    case rejected

    var title: String {
        switch self {
        case .pending:
            return "Request pending"
        case .rejected:
            return "Request rejected"
        }
    }

    var message: String {
        switch self {
        case .pending:
            return "This person needs to approve your request before you can chat."
        case .rejected:
            return "This request was rejected."
        }
    }
}
