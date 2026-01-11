import SwiftUI
import Foundation

struct ChatView: View {
    let conversation: Conversation?
    let channel: Channel?
    let onBackTapped: () -> Void

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var selectedMedia: [LocalMediaItem] = []
    @State private var showChatDetails = false
    @State private var conversationBackendId: Int?

    private var isGroupChat: Bool {
        return channel != nil
    }

    private var chatTitle: String {
        if let channel = channel {
            return channel.name
        } else if let conversation = conversation {
            return conversation.userName
        } else {
            return "Chat"
        }
    }

    private var profileImageUrl: String? {
        return conversation?.userProfileImageUrl
    }

    private var groupInitials: String {
        let rawTitle = channel?.name ?? conversation?.userName ?? "Group"
        let components = rawTitle.split(separator: " ")
        let initials = components.compactMap { component -> Character? in
            component.first { char in
                char.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
            }
        }
        .prefix(2)
        .map { String($0).uppercased() }
        .joined()

        return initials.isEmpty ? "GC" : initials
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack(spacing: 12) {
                // Back Button
                Button(action: onBackTapped) {
                    Image(systemName: "chevron.left")
                        .font(.loopedTitle2Scaled)
                        .foregroundColor(.loopedSecondary)
                }

                Image("logo-banner")
                    .resizable()
                    .scaledToFit()
                    .frame(height: bannerHeight)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                // Chat Title and Profile - Tappable
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
                        } else if isGroupChat {
                            Circle()
                                .fill(Color.loopedSecondary)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(groupInitials)
                                        .font(.loopedCustom(.medium, size: 12, relativeTo: .caption))
                                        .foregroundColor(.loopedWhite)
                                )
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .background(Color.loopedBackground)

            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let showTail = shouldShowTail(for: message, at: index, in: viewModel.messages)

                            if isMessageFromCurrentUser(message) {
                                SentMessageBubble(message: message, showTail: showTail)
                            } else {
                                ReceivedMessageBubble(
                                    message: message,
                                    showProfilePicture: isGroupChat,
                                    showSenderName: isGroupChat,
                                    showTail: showTail,
                                    onProfileTap: nil
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 16)
                }
                .onChange(of: viewModel.messages.count) { _ in
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
            .disabled(viewModel.messageRequestState != nil)
            .opacity(viewModel.messageRequestState == nil ? 1 : 0.6)
        }
        .background(Color.loopedBackground.ignoresSafeArea(.all))
        .sheet(isPresented: $showChatDetails) {
            ChatDetailsView(conversation: conversation, channel: channel)
        }
        .task {
            configureIds()
            await loadMessages()
        }
    }

    private var bannerHeight: CGFloat {
        horizontalSizeClass == .regular ? 80 : 60
    }

    private func isMessageFromCurrentUser(_ message: Message) -> Bool {
        guard let currentUserId = authViewModel.currentUser?.id else { return false }
        return message.senderId == currentUserId
    }

    private func sendMessage() {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !selectedMedia.isEmpty
        guard hasText || hasMedia else { return }

        Task {
            if let channel = channel {
                await viewModel.sendMessage(messageText, to: channel)
            } else {
                await viewModel.sendDirectMessage(messageText)
            }

            messageText = ""
            selectedMedia = []
        }
    }

    private func configureIds() {
        if let conversation = conversation {
            conversationBackendId = conversation.backendId
            viewModel.configure(conversationBackendId: conversation.backendId, channelBackendId: nil)
        } else if let channel = channel {
            viewModel.configure(conversationBackendId: nil, channelBackendId: channel.backendId)
        }
    }

    private func loadMessages() async {
        if let channel = channel {
            await viewModel.loadMessages(for: channel)
        } else {
            await viewModel.loadDirectMessages()
        }
    }

    private func shouldShowTail(for message: Message, at index: Int, in messages: [Message]) -> Bool {
        // Always show tail if this is the only message or the last message
        guard index < messages.count - 1 else { return true }

        // Check if the next message is from a different sender
        let nextMessage = messages[index + 1]
        return message.senderId != nextMessage.senderId
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
