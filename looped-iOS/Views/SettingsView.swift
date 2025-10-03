import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authViewModel = AuthViewModel()

    // Toggle states
    @State private var showFollowerCount = true
    @AppStorage("anonymousMode") private var anonymousMode = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SettingsHeader {
                dismiss()
            }

            // Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Account Section
                    SettingsSection(title: "Account") {
                        SettingsRow(icon: "person.circle", title: "User settings")
                        SettingsRow(icon: "shield", title: "Security")
                        SettingsRow(icon: "bell", title: "Notifications")
                        SettingsRow(icon: "lock", title: "Privacy and Data Protection")
                    }

                    // Support & About Section
                    SettingsSection(title: "Support & About") {
                        SettingsRow(icon: "doc.text", title: "Looped Rules")
                        SettingsRow(icon: "questionmark.circle", title: "Help & Support")
                        SettingsRow(icon: "info.circle", title: "Terms and Policies")
                        SettingsRow(icon: "doc.on.clipboard", title: "User Agreement")
                    }

                    // Content Interactions Section
                    SettingsSection(title: "Content Interactions") {
                        SettingsRow(title: "Liked post", isIndented: true)
                        SettingsRow(title: "Personal content", isIndented: true)
                    }

                    // Connected Accounts Section
                    SettingsSection(title: "Connected Accounts") {
                        ConnectedAccountRow(
                            icon: "google-logo",
                            title: "Google",
                            buttonText: "Connect",
                            buttonColor: .loopedPrimary,
                            isConnected: false
                        )
                        ConnectedAccountRow(
                            icon: "",
                            title: "Apple",
                            buttonText: "Disconnect",
                            buttonColor: .loopedPrimary,
                            isConnected: true,
                            isApple: true
                        )
                    }

                    // Safety Section
                    SettingsSection(title: "Safety") {
                        SettingsToggleRow(
                            icon: "person.2",
                            title: "Show Follower Count",
                            isOn: $showFollowerCount
                        )
                        SettingsRow(icon: "gear", title: "Messaging Permissions")
                        SettingsRow(icon: "person.2.slash", title: "Manage Blocked Accounts\nand Communities")
                        SettingsToggleRow(
                            icon: "theatermasks",
                            title: "Anonymous Mode",
                            isOn: $anonymousMode
                        )
                    }

                    // Actions Section
                    SettingsSection(title: "Actions") {
                        SettingsRow(icon: "flag", title: "Report a problem")
                        SettingsRow(icon: "building.2", title: "Change Workplace/Position")
                        SettingsRow(icon: "trash", title: "Delete Account")
                        SettingsRow(icon: "arrow.right.square", title: "Log out") {
                            authViewModel.signOut()
                        }
                    }

                    // Language Section
                    SettingsSection(title: "Language") {
                        SettingsRow(icon: "globe", title: "Display language")
                        SettingsRow(icon: "shield.checkered", title: "Content language")
                    }

                    // Content viewer policy Section
                    SettingsSection(title: "Content viewer policy") {
                        SettingsRow(icon: "doc.text", title: "Blocked")
                        SettingsRow(icon: "questionmark.circle", title: "Profanity")
                        SettingsRow(icon: "info.circle", title: "Content Preferences")
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Settings Header

struct SettingsHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
            }

            HStack(spacing: 2) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 24)

                Text("ooped")
                    .font(.loopedBody24)
                    .foregroundColor(.loopedContrast)
            }

            Spacer()

            Text("Settings")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
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
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                content
            }
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String?
    let title: String
    let textColor: Color
    let isIndented: Bool
    let action: (() -> Void)?

    init(
        icon: String? = nil,
        title: String,
        textColor: Color = .loopedTextPrimary,
        isIndented: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.textColor = textColor
        self.isIndented = isIndented
        self.action = action
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 4) {
                if !isIndented {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.loopedTextSecondary)
                            .frame(width: 20, height: 10)
                    }
                }

                Text(title)
                    .font(.loopedBodyMedium)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, isIndented ? 52 : 28)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.loopedTextSecondary)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.4, green: 0.7, blue: 0.6)))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Connected Account Row

struct ConnectedAccountRow: View {
    let icon: String
    let title: String
    let buttonText: String
    let buttonColor: Color
    let isConnected: Bool
    let isApple: Bool

    init(
        icon: String,
        title: String,
        buttonText: String,
        buttonColor: Color,
        isConnected: Bool,
        isApple: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.buttonText = buttonText
        self.buttonColor = buttonColor
        self.isConnected = isConnected
        self.isApple = isApple
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            if isApple {
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.loopedTextPrimary)
                    .frame(width: 20, height: 20)
            } else {
                // Google icon placeholder
                Text(icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.blue)
                    .clipShape(Circle())
            }

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Button(buttonText) {
                // Handle connection/disconnection
            }
            .font(.loopedSubBodyMedium)
            .foregroundColor(isConnected ? .loopedPrimary : .loopedPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

#Preview {
    SettingsView()
}
