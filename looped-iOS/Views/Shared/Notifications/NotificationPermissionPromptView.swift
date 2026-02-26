import SwiftUI
import UIKit

struct NotificationPermissionPromptView: View {
    let onDismiss: () -> Void

    @State private var isRequesting = false
    @State private var showSettingsAlert = false

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 14) {
                    Image(systemName: "bell.badge.fill")
                        .font(.loopedCustom(size: 52))
                        .foregroundColor(.loopedPrimary)
                        .accessibilityHidden(true)

                    Text("Enable Notifications")
                        .font(.loopedHeadingMedium)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Get notified about direct messages, mentions, and important updates. You can change this anytime in iOS Settings.")
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(
                        title: "Enable Notifications",
                        isEnabled: !isRequesting,
                        isLoading: isRequesting
                    ) {
                        requestPermission()
                    }

                    StyledButton(
                        title: "Not Now",
                        style: MutedSecondaryButtonStyle(),
                        isEnabled: !isRequesting
                    ) {
                        onDismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .alert("Notifications Disabled", isPresented: $showSettingsAlert) {
            Button("Open iOS Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
                onDismiss()
            }
            Button("Done", role: .cancel) {
                onDismiss()
            }
        } message: {
            Text("Looped can’t send you push notifications until they’re allowed in iOS Settings.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
    }
}

private extension NotificationPermissionPromptView {
    func requestPermission() {
        guard !isRequesting else { return }
        isRequesting = true

        Task {
            let granted = await NotificationAuthorizationManager.shared.requestAuthorization()
            if granted {
                await enablePushPreferencesBestEffort()
                await MainActor.run {
                    isRequesting = false
                    onDismiss()
                }
            } else {
                await MainActor.run {
                    isRequesting = false
                    showSettingsAlert = true
                }
            }
        }
    }

    func enablePushPreferencesBestEffort() async {
        var channels = NotificationChannelsUpdateDTO()
        channels.push = NotificationChannelUpdateDTO(enabled: true, types: nil)
        let update = NotificationPreferencesUpdateRequest(channels: channels)
        _ = try? await NotificationService().updatePreferences(update)
    }
}

#Preview {
    NotificationPermissionPromptView(onDismiss: {})
}
