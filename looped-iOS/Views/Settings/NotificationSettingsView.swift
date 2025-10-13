import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Push Notifications
    @State private var pushNotificationsEnabled = true
    @State private var postReplies = true
    @State private var directMessages = true
    @State private var mentions = true
    @State private var newFollowers = false
    @State private var postLikes = false

    // Email Notifications
    @State private var emailNotificationsEnabled = true
    @State private var emailDigest = true
    @State private var emailMarketing = false

    // In-App Notifications
    @State private var inAppSounds = true
    @State private var inAppBadges = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text("Notifications")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                // Invisible button for symmetry
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 12)

            // Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Push Notifications Section
                    NotificationSection(title: "Push Notifications") {
                        NotificationToggleRow(
                            icon: "bell.fill",
                            title: "Enable Push Notifications",
                            subtitle: "Receive notifications on this device",
                            isOn: $pushNotificationsEnabled,
                            isPrimary: true
                        )

                        if pushNotificationsEnabled {
                            Divider().padding(.horizontal, 16)

                            NotificationToggleRow(
                                icon: "bubble.left.and.bubble.right",
                                title: "Post Replies",
                                subtitle: "When someone replies to your post",
                                isOn: $postReplies
                            )

                            Divider().padding(.horizontal, 16)

                            NotificationToggleRow(
                                icon: "envelope.fill",
                                title: "Direct Messages",
                                subtitle: "When you receive a new message",
                                isOn: $directMessages
                            )

                            Divider().padding(.horizontal, 16)

                            NotificationToggleRow(
                                icon: "at",
                                title: "Mentions",
                                subtitle: "When someone mentions you",
                                isOn: $mentions
                            )

                            Divider().padding(.horizontal, 16)

                            NotificationToggleRow(
                                icon: "person.badge.plus",
                                title: "New Followers",
                                subtitle: "When someone follows you",
                                isOn: $newFollowers
                            )

                            Divider().padding(.horizontal, 16)

                            NotificationToggleRow(
                                icon: "heart.fill",
                                title: "Post Likes",
                                subtitle: "When someone likes your post",
                                isOn: $postLikes
                            )
                        }
                    }

                    // Email Notifications Section
                    NotificationSection(title: "Email Notifications") {
                        NotificationToggleRow(
                            icon: "envelope.circle.fill",
                            title: "Enable Email Notifications",
                            subtitle: "Receive updates via email",
                            isOn: $emailNotificationsEnabled,
                            isPrimary: true
                        )

                        if emailNotificationsEnabled {
                            Divider().padding(.horizontal, 16)

                            NotificationToggleRow(
                                icon: "calendar",
                                title: "Daily Digest",
                                subtitle: "Summary of activity",
                                isOn: $emailDigest
                            )

                            Divider().padding(.horizontal, 16)

                            NotificationToggleRow(
                                icon: "megaphone",
                                title: "Marketing & Updates",
                                subtitle: "Product news and features",
                                isOn: $emailMarketing
                            )
                        }
                    }

                    // In-App Preferences Section
                    NotificationSection(title: "In-App Preferences") {
                        NotificationToggleRow(
                            icon: "speaker.wave.2.fill",
                            title: "Notification Sounds",
                            subtitle: "Play sound for new notifications",
                            isOn: $inAppSounds
                        )

                        Divider().padding(.horizontal, 16)

                        NotificationToggleRow(
                            icon: "app.badge",
                            title: "Badge Count",
                            subtitle: "Show unread count on app icon",
                            isOn: $inAppBadges
                        )
                    }

                    // Quiet Hours Section
                    NotificationSection(title: "Quiet Hours") {
                        NotificationActionRow(
                            icon: "moon.fill",
                            title: "Do Not Disturb",
                            subtitle: "Set quiet hours schedule"
                        ) {
                            // TODO: Navigate to quiet hours settings
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 22 : 18, weight: .medium))
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
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.4, green: 0.7, blue: 0.6)))
                .onChange(of: isOn) { _ in
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                    .font(.system(size: 20, weight: .medium))
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
                    .font(.system(size: 14, weight: .semibold))
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
