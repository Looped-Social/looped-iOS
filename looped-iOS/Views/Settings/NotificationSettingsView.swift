import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationPreferencesViewModel()
    @State private var showPushPermissionAlert = false

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.preferences == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.loopedBackground)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedError)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.loopedBackground)
            }

            if viewModel.preferences != nil {
                privacySection
                deliverySection
                notificationTypesSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadPreferences()
        }
        .alert("Enable Push Notifications", isPresented: $showPushPermissionAlert) {
            Button("Open iOS Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Looped can’t send you push notifications until they’re allowed in iOS Settings.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
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
	                id: .messageRequest,
	                icon: "tray.fill",
	                title: "Message Requests",
	                subtitle: "When someone you don’t follow messages you",
	                isSystem: false
	            ),
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
                id: .sinceAwayHighlights,
                icon: "sparkles",
                title: "Highlights",
                subtitle: "Top posts since you were away",
                isSystem: false
            ),
            NotificationTypeDescriptor(
                id: .trendingToday,
                icon: "flame.fill",
                title: "Trending",
                subtitle: "When something is trending right now",
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

    var privacySection: some View {
        let isLoaded = viewModel.preferences != nil
        return Section("Privacy") {
            Toggle(isOn: privacyModeBinding) {
                SettingsRowLabel(
                    icon: .system("lock.fill"),
                    title: "Show Details on Lock Screen",
                    subtitle: "If off, push notifications use generic copy by default"
                )
            }
            .tint(.loopedSecondary)
            .disabled(!isLoaded)
        }
    }

    var deliverySection: some View {
        let isLoaded = viewModel.preferences != nil
        return Section("Delivery") {
            Toggle(isOn: channelEnabledBinding(.inApp)) {
                SettingsRowLabel(
                    icon: .system("app.badge"),
                    title: "In-App Notifications",
                    subtitle: "Show notifications inside the app"
                )
            }
            .tint(.loopedSecondary)
            .disabled(!isLoaded)

            Toggle(isOn: channelEnabledBinding(.push)) {
                SettingsRowLabel(
                    icon: .system("bell.fill"),
                    title: "Push Notifications",
                    subtitle: "Receive notifications on this device"
                )
            }
            .tint(.loopedSecondary)
            .disabled(!isLoaded)
        }
    }

    var notificationTypesSection: some View {
        let isLoaded = viewModel.preferences != nil
        return Section("Notification Types") {
            Text("Applies to all enabled delivery methods above.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .listRowBackground(Color.loopedBackground)

            ForEach(typeDescriptors) { descriptor in
                Toggle(isOn: typeBinding(type: descriptor.id)) {
                    SettingsRowLabel(
                        icon: .system(descriptor.icon),
                        title: descriptor.title,
                        subtitle: descriptor.subtitle
                    )
                }
                .tint(.loopedSecondary)
                .disabled(!isLoaded || descriptor.isSystem)
            }
        }
    }

    func channelEnabledBinding(_ channel: NotificationPreferenceChannel) -> Binding<Bool> {
        Binding(
            get: { viewModel.preferences?.channels.channel(channel).enabled ?? false },
            set: { newValue in
                Task {
                    if channel == .push, newValue {
                        let granted = await NotificationAuthorizationManager.shared.requestAuthorization()
                        guard granted else {
                            await MainActor.run { showPushPermissionAlert = true }
                            return
                        }
                    }
                    await viewModel.setChannelEnabled(channel, isOn: newValue)
                }
            }
        )
    }

    func typeBinding(type: NotificationPreferenceType) -> Binding<Bool> {
        let deliveryChannels: [NotificationPreferenceChannel] = channelsForType(type)
        return Binding(
            get: {
                guard let preferences = viewModel.preferences else { return false }
                return deliveryChannels.contains { channel in
                    preferences.channels.channel(channel).types.value(for: type)
                }
            },
            set: { newValue in
                Task { await viewModel.setTypeEnabled(type: type, isOn: newValue, channels: deliveryChannels) }
            }
        )
    }

    var privacyModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.preferences?.privacyMode == .detailed },
            set: { newValue in
                Task {
                    await viewModel.setPrivacyMode(newValue ? .detailed : .generic)
                }
            }
        )
    }

    func channelsForType(_ type: NotificationPreferenceType) -> [NotificationPreferenceChannel] {
        switch type {
        case .sinceAwayHighlights, .trendingToday:
            return [.push]
        default:
            return [.inApp, .push]
        }
    }
}

#Preview {
    NotificationSettingsView()
}
