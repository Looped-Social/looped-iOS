import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation
    
    private var groupInitials: String {
        let words = conversation.userName.split(separator: " ")
        let initials = words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return initials.isEmpty ? "GC" : initials
    }

    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture or Group Icon
            if conversation.isGroup {
                Circle()
                    .fill(Color.loopedSecondary)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(groupInitials)
                            .font(.loopedCustom(.semibold, size: 16))
                            .foregroundColor(.loopedWhite)
                    )
            } else {
                ProfileAvatarView(imageURL: conversation.userProfileImageUrl, size: 50)
            }

            // Content: Name and Last Message
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.userName)
                    .font(.loopedBodyStrong)
                    .foregroundColor(.loopedTextPrimary)

                HStack(spacing: 4) {
                    // Special status icon (like typing indicator or message status)
                    if conversation.hasSpecialStatus {
                        Image(systemName: "message.fill")
                            .font(.loopedCustom(size: 12))
                            .foregroundColor(.loopedPrimary)
                    }

                    Text(conversation.lastMessage)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right side: Timestamp and Unread indicator
            VStack(alignment: .trailing, spacing: 8) {
                Text(conversation.formattedTimestamp)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)

                // Unread count badge
                if conversation.hasUnreadMessages {
                    ZStack {
                        Circle()
                            .fill(Color.loopedSuccess)
                            .frame(width: 20, height: 20)

                        Text("\(conversation.unreadCount)")
                            .font(.loopedCustom(.medium, size: 12))
                            .foregroundColor(.loopedWhite)
                    }
                } else {
                    // Empty space to maintain alignment
                    Circle()
                        .fill(Color.loopedClear)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.loopedBackground)
    }
}

#Preview {
    VStack {
        // Preview with unread message
        ConversationRow(conversation: Conversation(
            userId: UUID(),
            userName: "Shivam",
            userProfileImageUrl: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Good Evening Bhai",
            lastMessageTimestamp: Date(),
            unreadCount: 1
        ))

        // Preview with special status
        ConversationRow(conversation: Conversation(
            userId: UUID(),
            userName: "Gurmeet",
            userProfileImageUrl: "https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Have a Great Day",
            lastMessageTimestamp: Date(),
            hasSpecialStatus: true
        ))

        // Preview normal message
        ConversationRow(conversation: Conversation(
            userId: UUID(),
            userName: "Anuj",
            userProfileImageUrl: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&crop=face",
            lastMessage: "Well Done",
            lastMessageTimestamp: Date()
        ))

        Spacer()
    }
    .background(Color.loopedBackground)
}
