import Foundation
import Combine
import SwiftUI
import UIKit

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
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadInbox() async {
        isLoading = true
        errorMessage = nil

        do {
            async let conversationsPage = messageService.listConversations(cursor: nil)
            async let requestsPage = messageService.fetchMessageRequests(cursor: nil)
            let (conversationResult, requestsResult) = try await (conversationsPage, requestsPage)
            conversations = conversationResult.conversations
            messageRequests = requestsResult.requests.filter { $0.status == .pending }
            await hydrateSenderProfiles(for: messageRequests)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
    
    private let messageService: MessageServiceProtocol
    private let messageMediaService: MessageMediaServiceProtocol
    private let webSocketService: WebSocketServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var conversationBackendId: Int?
    private var channelBackendId: Int?
    private var nextCursor: String?
    
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
    
    func configure(conversationBackendId: Int? = nil, channelBackendId: Int? = nil) {
        self.conversationBackendId = conversationBackendId
        self.channelBackendId = channelBackendId
    }
    
    func loadMessages(for channel: Channel) async {
        isLoading = true
        errorMessage = nil
        messageRequestState = nil

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
        messageRequestState = nil

        guard let conversationBackendId else {
            errorMessage = "Direct messages require a conversation ID."
            isLoading = false
            return
        }

        do {
            let page = try await messageService.getConversationMessages(conversationId: conversationBackendId, cursor: nil)
            messages = page.messages
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
            let message = try await messageService.sendChannelMessage(
                channelBackendId: channel.backendId,
                content: trimmedContent,
                attachments: attachments.isEmpty ? nil : attachments
            )
            messages.append(message)
            return true
        } catch {
            errorMessage = error.localizedDescription
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
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
            let message = try await messageService.sendConversationMessage(
                conversationId: conversationBackendId,
                content: trimmedContent,
                attachments: attachments.isEmpty ? nil : attachments
            )
            messages.append(message)
            return true
        } catch {
            handleDirectMessageError(error)
            toastMessage = ToastMessage(text: errorMessage ?? error.localizedDescription, kind: .error)
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
        errorMessage = error.localizedDescription
    }

    private func uploadAttachments(from media: [LocalMediaItem]) async throws -> [String] {
        guard !media.isEmpty else { return [] }
        var keys: [String] = []
        keys.reserveCapacity(media.count)

        for item in media {
            switch item.type {
            case .image:
                guard let image = item.image else { throw ChatMediaUploadError.unreadableImage }
                guard let payload = makeUploadPayload(from: image) else { throw ChatMediaUploadError.unreadableImage }
                let key = try await messageMediaService.uploadImage(data: payload.data, mimeType: payload.mimeType)
                keys.append(key)
            case .video:
                guard let url = item.videoURL else { throw ChatMediaUploadError.unreadableVideo }
                let mp4Url = try await VideoTranscoder.ensureMP4(at: url)
                let key = try await messageMediaService.uploadVideo(fileURL: mp4Url, mimeType: "video/mp4")
                keys.append(key)
            case .gif:
                throw ChatMediaUploadError.unsupportedMedia
            }
        }

        return keys
    }

    private func makeUploadPayload(from image: UIImage) -> ChatImageUploadPayload? {
        let resized = resizedImageIfNeeded(image, maxDimension: 2048)
        let width = Int(resized.size.width * resized.scale)
        let height = Int(resized.size.height * resized.scale)

        if imageHasAlpha(resized), let pngData = resized.pngData() {
            return ChatImageUploadPayload(data: pngData, mimeType: "image/png", width: width, height: height)
        }

        if let jpegData = resized.jpegData(compressionQuality: 0.85) {
            return ChatImageUploadPayload(data: jpegData, mimeType: "image/jpeg", width: width, height: height)
        }

        return nil
    }

    private func resizedImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let maxPixel = max(pixelWidth, pixelHeight)
        guard maxPixel > maxDimension, maxPixel > 0 else { return image }

        let scaleFactor = maxDimension / maxPixel
        let newSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
    
    private func setupWebSocketListeners() {
        webSocketService.messageReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                if self.messages.contains(where: { $0.backendId == message.backendId }) == false {
                    self.messages.append(message)
                }
            }
            .store(in: &cancellables)
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

    var errorDescription: String? {
        switch self {
        case .unsupportedMedia:
            return "That media type isn't supported in messages yet."
        case .unreadableImage:
            return "We couldn't read that image. Try another one."
        case .unreadableVideo:
            return "We couldn't read that video. Try another one."
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
