import SwiftUI

// MARK: - Sent Message Bubble (User's Messages)
struct SentMessageBubble: View {
    let message: Message
    let showTail: Bool

    init(message: Message, showTail: Bool = true) {
        self.message = message
        self.showTail = showTail
    }

    var body: some View {
        HStack {
            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(message.content)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Color.loopedMessageColor
                    )
                    .clipShape(TailCornerShape(isFromCurrentUser: true, showTail: showTail))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(formatMessageTime(message.createdAt))
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.leading, 60)
    }
}

// MARK: - Received Message Bubble (Other Users' Messages)
struct ReceivedMessageBubble: View {
    let message: Message
    let showProfilePicture: Bool
    let showSenderName: Bool
    let showTail: Bool

    init(message: Message, showProfilePicture: Bool, showSenderName: Bool, showTail: Bool = true) {
        self.message = message
        self.showProfilePicture = showProfilePicture
        self.showSenderName = showSenderName
        self.showTail = showTail
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Profile Picture (only for group chats)
            if showProfilePicture {
                AsyncImage(url: URL(string: "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedPrimary.opacity(0.3))
                        .overlay(
                            Text(String(message.senderDisplayName?.prefix(1) ?? "U").uppercased())
                                .font(.caption)
                                .foregroundColor(.loopedPrimary)
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                // Sender Name (only for group chats)
                if showSenderName {
                    Text(message.senderDisplayName ?? "Unknown User")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.leading, 4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Color.loopedMessageMutedColor
                        )
                        .clipShape(TailCornerShape(isFromCurrentUser: false, showTail: showTail))
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 3)

                    Text(formatMessageTime(message.createdAt))
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.leading, 4)
                }
            }

            Spacer()
        }
        .padding(.trailing, 60)
        .padding(.leading, showProfilePicture ? 0 : 20)
    }
}

// MARK: - Image Message Bubble (for handling image attachments)
struct ImageMessageBubble: View {
    let message: Message
    let imageUrl: String
    let showProfilePicture: Bool
    let showSenderName: Bool
    let isFromCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isFromCurrentUser {
                // Profile Picture (only for group chats and received messages)
                if showProfilePicture {
                    AsyncImage(url: URL(string: "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.loopedPrimary.opacity(0.3))
                            .overlay(
                                Text(String(message.senderDisplayName?.prefix(1) ?? "U").uppercased())
                                    .font(.caption)
                                    .foregroundColor(.loopedPrimary)
                            )
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                }
            }

            if isFromCurrentUser {
                Spacer()
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender Name (only for group chats and received messages)
                if showSenderName && !isFromCurrentUser {
                    Text(message.senderDisplayName ?? "Unknown User")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.leading, 4)
                }

                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Image with text overlay if there's content
                    VStack(spacing: 8) {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 200, height: 200)
                                .overlay(
                                    Text("IMG_\(String(imageUrl.suffix(4)))")
                                        .font(.loopedBodyMedium)
                                        .foregroundColor(.loopedTextSecondary)
                                )
                        }

                        if !message.content.isEmpty {
                            Text(message.content)
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextPrimary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isFromCurrentUser ? Color.white : Color(red: 0.7, green: 0.9, blue: 0.9))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )

                    Text(formatMessageTime(message.createdAt))
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.leading, isFromCurrentUser ? 0 : 4)
                        .padding(.trailing, isFromCurrentUser ? 4 : 0)
                }
            }

            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.leading, isFromCurrentUser ? 80 : (showProfilePicture ? 0 : 40))
        .padding(.trailing, isFromCurrentUser ? 0 : 80)
    }
}

// MARK: - Helper Functions
private func formatMessageTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    let calendar = Calendar.current

    if calendar.isDate(date, inSameDayAs: Date()) {
        formatter.dateFormat = "h:mm a"
    } else {
        formatter.dateFormat = "MMM d, h:mm a"
    }

    return formatter.string(from: date)
}

// MARK: - Previews
#Preview("Sent Message") {
    VStack(spacing: 16) {
        SentMessageBubble(
            message: Message(
                id: UUID(),
                content: "Good morning!",
                senderId: UUID(),
                senderDisplayName: "Current User",
                receiverId: UUID(),
                channelId: nil,
                messageType: .direct,
                isRead: true,
                createdAt: Date()
            ),
            showTail: true
        )
                ReceivedMessageBubble(
            message: Message(
                id: UUID(),
                content: "Japan looks amazing!",
                senderId: UUID(),
                senderDisplayName: "Big Bros",
                receiverId: UUID(),
                channelId: nil,
                messageType: .direct,
                isRead: true,
                createdAt: Date()
            ),
            showProfilePicture: false,
            showSenderName: false,
            showTail: true
        )

        SentMessageBubble(
            message: Message(
                id: UUID(),
                content: "This is a longer message to test how the bubble handles multiple lines of text properly with good spacing and alignment.",
                senderId: UUID(),
                senderDisplayName: "Current User",
                receiverId: UUID(),
                channelId: nil,
                messageType: .direct,
                isRead: true,
                createdAt: Date()
            ),
            showTail: false
        )
    }
    .padding()
    .background(Color.loopedBackground)
}

#Preview("Received Messages") {
    VStack(spacing: 16) {
        // Single chat message with tail
        ReceivedMessageBubble(
            message: Message(
                id: UUID(),
                content: "Japan looks amazing!",
                senderId: UUID(),
                senderDisplayName: "Big Bros",
                receiverId: UUID(),
                channelId: nil,
                messageType: .direct,
                isRead: true,
                createdAt: Date()
            ),
            showProfilePicture: false,
            showSenderName: false,
            showTail: true
        )
        
               ReceivedMessageBubble(
        
            message: Message(
                id: UUID(),
                content: "Japan looks amazing!",
                senderId: UUID(),
                senderDisplayName: "Big Bros",
                receiverId: UUID(),
                channelId: nil,
                messageType: .direct,
                isRead: true,
                createdAt: Date()
            ),
            showProfilePicture: false,
            showSenderName: false,
            showTail: true
        ) 
        

        // Group chat message with profile without tail
        ReceivedMessageBubble(
            message: Message(
                id: UUID(),
                content: "Wakey wakey",
                senderId: UUID(),
                senderDisplayName: "Team Member",
                receiverId: nil,
                channelId: UUID(),
                messageType: .channel,
                isRead: true,
                createdAt: Date()
            ),
            showProfilePicture: true,
            showSenderName: true,
            showTail: false
        )
    }
    .padding()
    .background(Color.loopedBackground)
}
