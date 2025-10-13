import SwiftUI

struct ChatView: View {
    let conversation: Conversation?
    let channel: Channel?
    let onBackTapped: () -> Void

    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var selectedMedia: [LocalMediaItem] = []
    @State private var showChatDetails = false

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

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack(spacing: 12) {
                // Back Button
                Button(action: onBackTapped) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.loopedSecondary)
                }

                HStack(spacing: 2) {
                    // Logo
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 32)

                    Text("ooped")
                        .font(.loopedHeading)
                        .foregroundColor(.loopedContrast)
                }
                .fixedSize(horizontal: true, vertical: false)
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

                        if !isGroupChat, let profileImageUrl = profileImageUrl {
                            AsyncImage(url: URL(string: profileImageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.loopedPrimary.opacity(0.3))
                                    .overlay(
                                        Text(String(chatTitle.prefix(1)).uppercased())
                                            .font(.caption)
                                            .foregroundColor(.loopedPrimary)
                                    )
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        } else if isGroupChat {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("VP")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.loopedBackground)

            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let showTail = shouldShowTail(for: message, at: index, in: viewModel.messages)

                            if message.senderId == MockUsers.currentUser.id {
                                SentMessageBubble(message: message, showTail: showTail)
                            } else {
                                ReceivedMessageBubble(
                                    message: message,
                                    showProfilePicture: isGroupChat,
                                    showSenderName: isGroupChat,
                                    showTail: showTail
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
            ChatInputView(
                messageText: $messageText,
                selectedMedia: $selectedMedia,
                onSendTapped: {
                    sendMessage()
                }
            )
        }
        .background(Color.loopedBackground.ignoresSafeArea(.all))
        .sheet(isPresented: $showChatDetails) {
            ChatDetailsView(conversation: conversation, channel: channel)
        }
        .task {
            await loadMessages()
        }
    }

    private func sendMessage() {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !selectedMedia.isEmpty
        guard hasText || hasMedia else { return }

        Task {
            if let channel = channel {
                await viewModel.sendMessage(messageText, to: channel)
            } else if let conversation = conversation {
                await viewModel.sendDirectMessage(messageText, to: conversation.userId)
            }

            messageText = ""
            selectedMedia = []
        }
    }

    private func loadMessages() async {
        if let channel = channel {
            await viewModel.loadMessages(for: channel)
        } else if let conversation = conversation {
            await viewModel.loadDirectMessages(with: conversation.userId)
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
}
