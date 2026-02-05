import SwiftUI
import Foundation
import UIKit

struct ChatView: View {
    enum PresentationStyle {
        case overlay
        case navigation
    }

    let conversation: Conversation?
    let channel: Channel?
    let conversationId: Int?
    let channelId: Int?
    let presentationStyle: PresentationStyle
    let onBackTapped: () -> Void

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var selectedMedia: [LocalMediaItem] = []
    @State private var showChatDetails = false
    @State private var conversationBackendId: Int?
    @State private var participantHandle: String?
    @State private var participantDisplayName: String?
    @State private var channelNameOverride: String?
    @State private var channelPhotoUrlOverride: String?? = nil

    init(
        conversation: Conversation?,
        channel: Channel?,
        conversationId: Int? = nil,
        channelId: Int? = nil,
        presentationStyle: PresentationStyle = .overlay,
        onBackTapped: @escaping () -> Void
    ) {
        self.conversation = conversation
        self.channel = channel
        self.conversationId = conversationId
        self.channelId = channelId
        self.presentationStyle = presentationStyle
        self.onBackTapped = onBackTapped
    }

    private var isGroupChat: Bool {
        return channel != nil || channelId != nil
    }

    private var chatTitle: String {
        if let channel = channel {
            return channelNameOverride ?? channel.name
        } else if let conversation = conversation {
            return conversation.userName
        } else if channelId != nil {
            return "Channel"
        } else if conversationId != nil {
            return "Conversation"
        } else {
            return "Chat"
        }
    }

    private var profileImageUrl: String? {
        return conversation?.userProfileImageUrl
    }

    var body: some View {
        VStack(spacing: 0) {
            if presentationStyle == .overlay {
                headerBar
            }

            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            if shouldShowDaySeparator(at: index, in: viewModel.messages) {
                                ChatDaySeparatorView(date: message.createdAt)
                                    .padding(.vertical, 8)
                            }

                            let isFromCurrentUser = isMessageFromCurrentUser(message)
                            let isStartOfGroup = isMessageGroupStart(at: index, in: viewModel.messages)
                            let isEndOfGroup = isMessageGroupEnd(at: index, in: viewModel.messages)
                            let bottomPadding = messageSpacingAfter(at: index, in: viewModel.messages)

                            Group {
                                if isFromCurrentUser {
                                    HStack(alignment: .bottom, spacing: 0) {
                                        SentMessageBubble(message: message, isGroupStart: isStartOfGroup, isGroupEnd: isEndOfGroup)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                } else {
                                    HStack(alignment: .bottom, spacing: 8) {
                                        if isGroupChat {
                                            if isEndOfGroup {
                                                ProfileAvatarView(imageURL: viewModel.senderAvatarURL(for: message), size: 32)
                                            } else {
                                                Rectangle()
                                                    .fill(Color.loopedClear)
                                                    .frame(width: 32, height: 32)
                                            }
                                        }
                                        ReceivedMessageBubble(
                                            message: message,
                                            showSenderName: isGroupChat && isStartOfGroup,
                                            isGroupStart: isStartOfGroup,
                                            isGroupEnd: isEndOfGroup
                                        )
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.bottom, bottomPadding)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                }
                .modifier(ChatKeyboardDismissalModifier(onDismiss: dismissKeyboard))
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input Area
            if let requestState = viewModel.messageRequestState {
                MessageRequestStatusBanner(state: requestState)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            ChatInputView(
                messageText: $messageText,
                selectedMedia: $selectedMedia,
                onSendTapped: {
                    sendMessage()
                }
            )
            .disabled(viewModel.messageRequestState != nil || viewModel.isSending)
            .opacity((viewModel.messageRequestState == nil && !viewModel.isSending) ? 1 : 0.6)
        }
        .background(Color.loopedBackground.ignoresSafeArea(.all))
        .toast($viewModel.toastMessage)
        .sheet(isPresented: $showChatDetails) {
            ChatDetailsView(conversation: conversation, channel: channel, onChatShouldClose: onBackTapped)
        }
        .task {
            configureIds()
            await loadParticipantInfoIfNeeded()
            await loadMessages()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
            for item in selectedMedia {
                TemporaryMediaFile.deleteIfOwned(item.videoURL)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Foundation.Notification.Name("ChatChannelUpdated"))) { notification in
            let currentChannelId = channel?.backendId ?? channelId
            guard let updatedChannelId = notification.userInfo?["channelBackendId"] as? Int,
                  let currentChannelId,
                  updatedChannelId == currentChannelId
            else { return }

            if let updatedName = notification.userInfo?["name"] as? String {
                let trimmed = updatedName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    channelNameOverride = trimmed
                }
            }

            if let rawPhotoValue = notification.userInfo?["photoUrl"] {
                if rawPhotoValue is NSNull {
                    channelPhotoUrlOverride = .some(nil)
                } else if let rawPhotoUrl = rawPhotoValue as? String {
                    channelPhotoUrlOverride = .some(rawPhotoUrl)
                }
            }
        }
        .modifier(ChatPresentationModifier(style: presentationStyle, titleView: chatToolbarTitle, onBackTapped: onBackTapped))
    }

    private var bannerHeight: CGFloat {
        horizontalSizeClass == .regular ? 80 : 60
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            LoopedBackButton(action: onBackTapped)

            Image("logo-banner")
                .resizable()
                .scaledToFit()
                .frame(height: bannerHeight)
                .layoutPriority(1)

            Spacer(minLength: 8)

            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                showChatDetails = true
            }) {
                HStack(spacing: 8) {
                    Text(chatTitle)
                        .font(.loopedBodyStrong)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !isGroupChat {
                        ProfileAvatarView(imageURL: profileImageUrl, size: 32)
                    } else {
                        GroupAvatarView(name: chatTitle, photoUrl: channelPhotoUrlOverride ?? channel?.photoUrl, size: 32)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .background(Color.loopedBackground)
    }

    private var chatSubtitle: String? {
        if isGroupChat {
            let count = channel?.memberCount ?? 0
            if count > 0 {
                return "\(count) members"
            }
            return "Group chat"
        }

        if let participantHandle, !participantHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = participantHandle.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("@") { return trimmed }
            return "@\(trimmed)"
        }
        return nil
    }

    private var chatToolbarTitle: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            showChatDetails = true
        }) {
            HStack(spacing: 8) {
                if isGroupChat {
                    GroupAvatarView(name: chatTitle, photoUrl: channel?.photoUrl, size: 28)
                } else {
                    ProfileAvatarView(imageURL: profileImageUrl, size: 28)
                }

                Text(participantDisplayName ?? chatTitle)
                    .font(.loopedBodyStrong)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.loopedMutedBackground.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chat details")
    }

    private func loadParticipantInfoIfNeeded() async {
        guard !isGroupChat else { return }
        guard participantHandle == nil && participantDisplayName == nil else { return }
        let backendUserId = conversation?.backendUserId ?? conversation?.userId.backendInt
        guard let backendUserId else { return }

        let userService: UserServiceProtocol = UserService()
        do {
            let user = try await userService.getUser(by: backendUserId)
            await MainActor.run {
                participantDisplayName = user.displayName ?? user.username
                participantHandle = user.handle
            }
        } catch {
            // Best-effort only; keep existing title if this fails.
        }
    }

    private func isMessageFromCurrentUser(_ message: Message) -> Bool {
        guard let currentUserId = authViewModel.currentUser?.id else { return false }
        return message.senderId == currentUserId
    }

    private func sendMessage() {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !selectedMedia.isEmpty
        guard hasText || hasMedia else { return }

        let contentToSend = messageText
        let mediaToSend = selectedMedia

        Task {
            let didSend: Bool
            if let channelBackendId = channel?.backendId ?? channelId {
                if let channel {
                    didSend = await viewModel.sendMessage(contentToSend, media: mediaToSend, to: channel)
                } else {
                    didSend = await viewModel.sendChannelMessage(channelBackendId: channelBackendId, content: contentToSend, media: mediaToSend)
                }
            } else {
                didSend = await viewModel.sendDirectMessage(contentToSend, media: mediaToSend)
            }

            guard didSend else { return }
            for item in mediaToSend {
                TemporaryMediaFile.deleteIfOwned(item.videoURL)
            }
            messageText = ""
            selectedMedia = []
        }
    }

    private func configureIds() {
        if let conversation = conversation {
            conversationBackendId = conversation.backendId
            viewModel.configure(conversationBackendId: conversation.backendId, channelBackendId: nil)
        } else if let conversationId {
            conversationBackendId = conversationId
            viewModel.configure(conversationBackendId: conversationId, channelBackendId: nil)
        } else if let channel = channel {
            viewModel.configure(conversationBackendId: nil, channelBackendId: channel.backendId)
        } else if let channelId {
            viewModel.configure(conversationBackendId: nil, channelBackendId: channelId)
        }
    }

    private func loadMessages() async {
        if let channel = channel {
            await viewModel.loadMessages(for: channel)
        } else if let channelId {
            await viewModel.loadChannelMessages(channelBackendId: channelId)
        } else {
            await viewModel.loadDirectMessages()
            notifyConversationReadIfNeeded()
        }
    }

    private var messageGroupTimeThreshold: TimeInterval { 30 * 60 }

    private func shouldShowDaySeparator(at index: Int, in messages: [Message]) -> Bool {
        guard index < messages.count else { return false }
        guard index > 0 else { return true }

        let previous = messages[index - 1]
        let current = messages[index]
        return !Calendar.current.isDate(previous.createdAt, inSameDayAs: current.createdAt)
    }

    private func isSameMessageGroup(_ first: Message, _ second: Message) -> Bool {
        guard first.senderId == second.senderId else { return false }
        guard Calendar.current.isDate(first.createdAt, inSameDayAs: second.createdAt) else { return false }
        return second.createdAt.timeIntervalSince(first.createdAt) <= messageGroupTimeThreshold
    }

    private func isMessageGroupStart(at index: Int, in messages: [Message]) -> Bool {
        guard index < messages.count else { return false }
        guard index > 0 else { return true }
        return !isSameMessageGroup(messages[index - 1], messages[index])
    }

    private func isMessageGroupEnd(at index: Int, in messages: [Message]) -> Bool {
        guard index < messages.count else { return false }
        guard index < messages.count - 1 else { return true }
        return !isSameMessageGroup(messages[index], messages[index + 1])
    }

    private func messageSpacingAfter(at index: Int, in messages: [Message]) -> CGFloat {
        guard index < messages.count - 1 else { return 0 }
        let current = messages[index]
        let next = messages[index + 1]

        if !Calendar.current.isDate(current.createdAt, inSameDayAs: next.createdAt) {
            return 0
        }

        let delta = next.createdAt.timeIntervalSince(current.createdAt)
        if delta > messageGroupTimeThreshold {
            return 14
        }

        if current.senderId != next.senderId {
            return 8
        }

        return 1
    }
}

private struct ChatKeyboardDismissalModifier: ViewModifier {
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollDismissesKeyboard(.interactively)
                .loopedDismissKeyboardOnTap(onDismiss)
                .simultaneousGesture(TapGesture().onEnded { onDismiss() })
        } else {
            content
                .simultaneousGesture(DragGesture(minimumDistance: 1).onChanged { _ in onDismiss() })
                .loopedDismissKeyboardOnTap(onDismiss)
                .simultaneousGesture(TapGesture().onEnded { onDismiss() })
        }
    }
}

private extension ChatView {
    func dismissKeyboard() {
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    func notifyConversationReadIfNeeded() {
        guard let conversationBackendId else { return }
        guard viewModel.errorMessage == nil else { return }
        NotificationCenter.default.post(
            name: Foundation.Notification.Name("ChatConversationReadUpdate"),
            object: nil,
            userInfo: ["conversationBackendId": conversationBackendId]
        )
    }
}

private struct ChatPresentationModifier<TitleView: View>: ViewModifier {
    let style: ChatView.PresentationStyle
    let titleView: TitleView
    let onBackTapped: () -> Void

    func body(content: Content) -> some View {
        switch style {
        case .overlay:
            content
                .edgeSwipeToDismiss { onBackTapped() }
        case .navigation:
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        titleView
                    }
                }
        }
    }
}

private struct ChatDaySeparatorView: View {
    let date: Date

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return Self.monthDayFormatter.string(from: date)
    }

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Text(title)
                .font(.loopedSmallTextMedium)
                .foregroundColor(.loopedTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.loopedMutedBackground)
                )
            Spacer(minLength: 0)
        }
    }
}

private struct MessageRequestStatusBanner: View {
    let state: MessageRequestBlockState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state == .pending ? "clock.fill" : "xmark.octagon.fill")
                .foregroundColor(.loopedPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.loopedSubBodyBold)
                    .foregroundColor(.loopedTextPrimary)

                Text(state.message)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.loopedMutedBackground)
        )
    }
}


#Preview {
    ChatView(
        conversation: Conversation(
            userId: UUID(),
            userName: "Big Bros",
            userProfileImageUrl: nil,
            lastMessage: "Good morning!",
            lastMessageTimestamp: Date()
        ),
        channel: nil,
        onBackTapped: {}
    )
    .environmentObject(AuthViewModel())
}
