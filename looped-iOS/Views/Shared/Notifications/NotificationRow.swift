import SwiftUI

struct NotificationRow: View {
    let notification: Notification
    let actionTitle: String?
    let isActionLoading: Bool
    let isActionEnabled: Bool
    let onActionTapped: (() -> Void)?
    let onActorTapped: (() -> Void)?

    init(
        notification: Notification,
        actionTitle: String? = nil,
        isActionLoading: Bool = false,
        isActionEnabled: Bool = true,
        onActionTapped: (() -> Void)? = nil,
        onActorTapped: (() -> Void)? = nil
    ) {
        self.notification = notification
        self.actionTitle = actionTitle
        self.isActionLoading = isActionLoading
        self.isActionEnabled = isActionEnabled
        self.onActionTapped = onActionTapped
        self.onActorTapped = onActorTapped
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Picture
            Group {
                if notification.actorIsAnonymous && notification.type != .announcement && notification.type != .system {
                    Circle()
                        .fill(Color.loopedPrimary.opacity(0.2))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.loopedCustom(.semibold, size: 16))
                                .foregroundColor(.loopedPrimary)
                        )
                        .frame(width: 40, height: 40)
                } else {
                    ProfileAvatarView(imageURL: notification.actorProfileImageUrl, size: 40)
                }
            }
            .onTapGesture {
                guard !notification.actorIsAnonymous else { return }
                onActorTapped?()
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Notification Text
                HStack(alignment: .top, spacing: 6) {
                    notificationTextView
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    // Unread Indicator
                    if !notification.isRead {
                        Circle()
                            .fill(Color.loopedSecondary)
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                    }

                    // Timestamp
                    Text(notification.relativeTimeString)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(1)
                }

                // Content Preview (for post/comment notifications)
                if let previewText = notification.previewText, !previewText.isEmpty {
                    Text(previewText)
                        .font(.loopedSmallText)
                        .lineLimit(2)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.loopedMutedBackground)
                        .cornerRadius(8)
                }

                // Action Button (for follow/invite notifications)
                if let actionTitle, !actionTitle.isEmpty {
                    Button(action: {
                        onActionTapped?()
                    }) {
                        notificationActionButtonLabel(title: actionTitle)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                    .disabled(isActionLoading || !isActionEnabled)
                }
            }


        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(notification.isRead ? Color.loopedBackground : Color.loopedBackground.opacity(0.98))
    }

    // MARK: - Helper Properties
    private var notificationTextView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if onActorTapped != nil, !notification.actorIsAnonymous {
                Button(action: { onActorTapped?() }) {
                    Text(notification.actorName)
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text(notification.actorName)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
            }

            Text(notificationSuffixText)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextPrimary)
        }
    }

    private var notificationSuffixText: String {
        let full = notification.notificationText
        if full.hasPrefix(notification.actorName) {
            return String(full.dropFirst(notification.actorName.count))
        }
        if let range = full.range(of: notification.actorName) {
            return String(full[range.upperBound...])
        }
        return full
    }

    @ViewBuilder
    private func notificationActionButtonLabel(title: String) -> some View {
        let style = actionButtonStyle(for: title)
        let textColor: Color = {
            guard isActionEnabled else { return .loopedTextSecondary.opacity(0.75) }
            switch style {
            case .filled:
                return .loopedWhite
            case .outline:
                return .loopedTextSecondary
            }
        }()

        let background: Color = {
            guard isActionEnabled else { return .loopedMutedBackground.opacity(0.35) }
            switch style {
            case .filled:
                return .loopedPrimary
            case .outline:
                return .loopedClear
            }
        }()

        let borderColor: Color = {
            guard isActionEnabled else { return .loopedTextSecondary.opacity(0.2) }
            switch style {
            case .filled:
                return background
            case .outline:
                return .loopedTextSecondary
            }
        }()

        HStack(spacing: 8) {
            Text(title)
                .font(.loopedSubBodyRegular)
                .foregroundColor(textColor)

            if isActionLoading {
                ProgressView()
                    .tint(textColor)
                    .scaleEffect(0.85)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .fixedSize(horizontal: true, vertical: false)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private enum NotificationActionButtonStyle {
        case outline
        case filled
    }

    private func actionButtonStyle(for title: String) -> NotificationActionButtonStyle {
        switch notification.type {
        case .follow:
            return title == "Following" ? .filled : .outline
        case .loopInvite, .groupInvite:
            return .filled
        default:
            return .outline
        }
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
            actionTitle: "Follow Back",
            onActionTapped: { }
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
