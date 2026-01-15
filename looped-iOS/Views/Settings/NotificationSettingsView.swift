import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NotificationPreferencesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.loopedCustom(.medium, size: 24))
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text("Notifications")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                // Invisible button for symmetry
                Image(systemName: "chevron.left")
                    .font(.loopedCustom(.medium, size: 24))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 12)

            // Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.preferences == nil {
                        ProgressView()
                            .padding(.top, 24)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                    }

                    if viewModel.preferences != nil {
                        channelSection(
                            title: "In-App Notifications",
                            channel: .inApp,
                            primaryIcon: "app.badge",
                            primarySubtitle: "Show notifications inside the app"
                        )

                        channelSection(
                            title: "Push Notifications",
                            channel: .push,
                            primaryIcon: "bell.fill",
                            primarySubtitle: "Receive notifications on this device"
                        )

                        channelSection(
                            title: "Email Notifications",
                            channel: .email,
                            primaryIcon: "envelope.circle.fill",
                            primarySubtitle: "Receive updates via email"
                        )
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadPreferences()
        }
    }
}

private extension NotificationSettingsView {
    struct NotificationTypeDescriptor: Identifiable {
        let id: NotificationPreferenceType
        let icon: String
        let title: String
        let subtitle: String
        let isSystem: Bool
    }

    var typeDescriptors: [NotificationTypeDescriptor] {
        [
            NotificationTypeDescriptor(
                id: .dmMessage,
                icon: "message.fill",
                title: "Direct Messages",
                subtitle: "When someone messages you",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .channelMessage,
                icon: "bubble.left.and.bubble.right.fill",
                title: "Channel Messages",
                subtitle: "When there’s new activity in a channel",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .follow,
                icon: "person.badge.plus",
                title: "New Followers",
                subtitle: "When someone follows you",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .like,
                icon: "heart.fill",
                title: "Post Likes",
                subtitle: "When someone likes your post",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .comment,
                icon: "bubble.left.fill",
                title: "Comments",
                subtitle: "When someone comments on your post",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .reply,
                icon: "arrowshape.turn.up.left.fill",
                title: "Replies",
                subtitle: "When someone replies to your comment",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .mention,
                icon: "at",
                title: "Mentions",
                subtitle: "When someone mentions you",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .repost,
                icon: "arrow.2.squarepath",
                title: "Reposts",
                subtitle: "When someone reposts your post",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .postFromFollowed,
                icon: "person.2.fill",
                title: "Posts From Followed",
                subtitle: "When someone you follow posts",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .announcement,
                icon: "megaphone.fill",
                title: "Announcements",
                subtitle: "Company updates and broadcasts",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .system,
                icon: "gearshape.fill",
                title: "System",
                subtitle: "Important system alerts",
                isSystem: true
            )
        ]
    }

    @ViewBuilder
    func channelSection(
        title: String,
        channel: NotificationPreferenceChannel,
        primaryIcon: String,
        primarySubtitle: String
    ) -> some View {
        let isLoaded = viewModel.preferences != nil
        let isEnabled = viewModel.preferences?.channels.channel(channel).enabled ?? false
        NotificationSection(title: title) {
            NotificationToggleRow(
                icon: primaryIcon,
                title: "Enable \(title)",
                subtitle: primarySubtitle,
                isOn: channelEnabledBinding(channel),
                isPrimary: true,
                isDisabled: !isLoaded
            )

            if isEnabled {
                ForEach(typeDescriptors.indices, id: \.self) { index in
                    let descriptor = typeDescriptors[index]
                    Divider().padding(.horizontal, 16)
                    NotificationToggleRow(
                        icon: descriptor.icon,
                        title: descriptor.title,
                        subtitle: descriptor.subtitle,
                        isOn: typeBinding(channel: channel, type: descriptor.id),
                        isDisabled: !isLoaded || descriptor.isSystem
                    )
                }
            }
        }
    }

    func channelEnabledBinding(_ channel: NotificationPreferenceChannel) -> Binding<Bool> {
        Binding(
            get: { viewModel.preferences?.channels.channel(channel).enabled ?? false },
            set: { newValue in
                Task { await viewModel.setChannelEnabled(channel, isOn: newValue) }
            }
        )
    }

    func typeBinding(
        channel: NotificationPreferenceChannel,
        type: NotificationPreferenceType
    ) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.preferences?.channels.channel(channel).types.value(for: type) ?? false
            },
            set: { newValue in
                Task { await viewModel.setTypeEnabled(channel: channel, type: type, isOn: newValue) }
            }
        )
    }
}

// MARK: - Notification Section

struct NotificationSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.loopedBodyStrong)
                .foregroundColor(.loopedTextPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            .background(Color.loopedTextSecondary.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Notification Toggle Row

struct NotificationToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var isPrimary: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.loopedCustom(.medium, size: isPrimary ? 22 : 18))
                .foregroundColor(isPrimary ? .loopedPrimary : .loopedSecondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isPrimary ? .loopedBodyStrong : .loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Text(subtitle)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color.loopedSecondary))
                .onChange(of: isOn) { _ in
                    if !isDisabled {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

// MARK: - Notification Action Row

struct NotificationActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.loopedCustom(.medium, size: 20))
                    .foregroundColor(.loopedSecondary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(subtitle)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.loopedCustom(.semibold, size: 14))
                    .foregroundColor(.loopedTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NotificationSettingsView()
}
