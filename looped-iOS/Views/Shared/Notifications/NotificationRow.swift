import SwiftUI

struct NotificationRow: View {
    let notification: Notification
    let onActionTapped: (() -> Void)?

    init(notification: Notification, onActionTapped: (() -> Void)? = nil) {
        self.notification = notification
        self.onActionTapped = onActionTapped
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Picture
            AsyncImage(url: URL(string: notification.actorProfileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.loopedPrimary.opacity(0.2))
                    .overlay(
                        Text(String(notification.actorName.prefix(1)).uppercased())
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedPrimary)
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Notification Text
                HStack(alignment: .top, spacing: 6) {
                    // Notification text with attributed string
                    Text(notificationAttributedText)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    // Timestamp
                    Text(notification.relativeTimeString)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(1)
                }

                // Content Preview (for post/comment notifications)
                if let targetContent = notification.targetContent, !targetContent.isEmpty {
                    Text(targetContent)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(2)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.loopedMutedBackground)
                        .cornerRadius(8)
                }

                // Action Button (for follow/invite notifications)
                if notification.hasActionButton {
                    Button(action: {
                        onActionTapped?()
                    }) {
                        Text(notification.actionButtonText)
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedBackground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.loopedPrimary)
                            .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
            }

            // Unread Indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(notification.isRead ? Color.loopedBackground : Color.loopedBackground.opacity(0.98))
    }

    // MARK: - Helper Properties
    private var notificationAttributedText: AttributedString {
        var text = AttributedString(notification.notificationText)

        // Find and bold the actor name
        if let range = text.range(of: notification.actorName) {
            text[range].font = .loopedSubBodyMedium
            text[range].foregroundColor = .loopedTextPrimary
        }

        return text
    }
}

#Preview {
    VStack(spacing: 0) {
        // Like notification
        NotificationRow(
            notification: Notification(
                type: .like,
                actorId: UUID(),
                actorName: "Sarah Chen",
                actorProfileImageUrl: "https://via.placeholder.com/40",
                targetContent: "Just shipped a major feature! 🚀 The new search functionality is lightning fast.",
                isRead: false,
                createdAt: Date().addingTimeInterval(-3600)
            )
        )

        Divider()
            .padding(.leading, 68)

        // Comment notification with grouped actors
        NotificationRow(
            notification: Notification(
                type: .comment,
                actorId: UUID(),
                actorName: "Mike Rodriguez",
                actorProfileImageUrl: "https://via.placeholder.com/40",
                additionalActors: [
                    NotificationActor(name: "Alex Kim"),
                    NotificationActor(name: "Jennifer Liu")
                ],
                targetContent: "Remote work productivity tips that actually work",
                isRead: true,
                createdAt: Date().addingTimeInterval(-7200)
            )
        )

        Divider()
            .padding(.leading, 68)

        // Follow notification with action button
        NotificationRow(
            notification: Notification(
                type: .follow,
                actorId: UUID(),
                actorName: "David Park",
                actorProfileImageUrl: "https://via.placeholder.com/40",
                isRead: false,
                createdAt: Date().addingTimeInterval(-14400)
            ),
            onActionTapped: {
                print("Follow Back tapped")
            }
        )

        Divider()
            .padding(.leading, 68)

        // Mention notification
        NotificationRow(
            notification: Notification(
                type: .mention,
                actorId: UUID(),
                actorName: "Emily Watson",
                actorProfileImageUrl: "https://via.placeholder.com/40",
                targetContent: "Hot take: our current sprint planning process is broken. We consistently overcommit...",
                isRead: true,
                createdAt: Date().addingTimeInterval(-86400)
            )
        )

        Spacer()
    }
    .background(Color.loopedBackground)
}
