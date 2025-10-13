import SwiftUI

// MARK: - Icon Source Enum

enum IconSource {
    case system(String)  // SF Symbol
    case asset(String)   // Asset from Assets.xcassets
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authViewModel = AuthViewModel()

    // Toggle states
    @State private var showFollowerCount = true
    @AppStorage("anonymousMode") private var anonymousMode = true

    // Alert states
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false

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
                            NavigationLink(destination: UserSettingsView()) {
                                SettingsNavigationRow(icon: .asset("user-settings-icon"), title: "User settings")
                            }
                            .buttonStyle(PlainButtonStyle())

                            NavigationLink(destination: SecurityView()) {
                                SettingsNavigationRow(icon: .asset("shield-icon"), title: "Security")
                            }
                            .buttonStyle(PlainButtonStyle())

                            NavigationLink(destination: NotificationSettingsView()) {
                                SettingsNavigationRow(icon: .asset("bell-icon"), title: "Notifications")
                            }
                            .buttonStyle(PlainButtonStyle())

                            SettingsRow(icon: .asset("lock-icon"), title: "Privacy and Data Protection")
                        }

                    // Support & About Section
                    SettingsSection(title: "Support & About") {
                        SettingsRow(icon: .asset("rules-icon"), title: "Looped Rules")
                        SettingsRow(icon: .asset("help-icon"), title: "Help & Support")
                        SettingsRow(icon: .asset("terms-and-policies-icon"), title: "Terms and Policies")
                        SettingsRow(icon: .asset("user-agreement-icon"), title: "User Agreement")
                    }

                    // Content Interactions Section
                    SettingsSection(title: "Content Interactions") {
                        SettingsRow(title: "Liked post", isIndented: true)
                        SettingsRow(title: "Personal content", isIndented: true)
                    }

                    // Connected Accounts Section
                    SettingsSection(title: "Connected Accounts") {
                        ConnectedAccountRow(
                            icon: .asset("google-logo"),
                            title: "Google",
                            buttonText: "Connect",
                            buttonColor: .loopedSecondary,
                            isConnected: false
                        )
                        ConnectedAccountRow(
                            icon: .asset("apple-logo"),
                            title: "Apple",
                            buttonText: "Disconnect",
                            buttonColor: .loopedSecondary,
                            isConnected: true
                        )
                    }

                    // Safety Section
                    SettingsSection(title: "Safety") {
                        SettingsToggleRow(
                            icon: .asset("follower-count-icon"),
                            title: "Show Follower Count",
                            isOn: $showFollowerCount
                        )
                        SettingsRow(icon: .asset("message-permisions-icon"), title: "Messaging Permissions")
                        SettingsRow(icon: .asset("blocked-icon"), title: "Manage Blocked Accounts\nand Communities")
                        SettingsToggleRow(
                            icon: .system("theatermasks"),
                            title: "Anonymous Mode",
                            isOn: $anonymousMode
                        )
                    }

                    // Actions Section
                    SettingsSection(title: "Actions") {
                        SettingsRow(icon: .system("flag"), title: "Report a problem")
                        SettingsRow(icon: .system("building.2"), title: "Change Workplace/Position")
                        SettingsRow(icon: .system("trash"), title: "Delete Account") {
                            showDeleteAccountAlert = true
                        }
                        SettingsRow(icon: .asset("log-out-icon"), title: "Log out", textColor: .red) {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showLogoutAlert = true
                        }
                    }

                    // Language Section
                    SettingsSection(title: "Language") {
                        SettingsRow(icon: .system("globe"), title: "Display language")
                        SettingsRow(icon: .system("shield.checkered"), title: "Content language")
                    }

                    // Content viewer policy Section
                    SettingsSection(title: "Content viewer policy") {
                        SettingsRow(icon: .system("doc.text"), title: "Blocked")
                        SettingsRow(icon: .system("questionmark.circle"), title: "Profanity")
                        SettingsRow(icon: .system("info.circle"), title: "Content Preferences")
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert("Log out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log out", role: .destructive) {
                authViewModel.signOut()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // TODO: Implement delete account functionality
            }
        } message: {
            Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
        }
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
    let icon: IconSource?
    let title: String
    let textColor: Color
    let isIndented: Bool
    let action: (() -> Void)?

    init(
        icon: IconSource? = nil,
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
                        switch icon {
                        case .system(let name):
                            Image(systemName: name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.loopedTextSecondary)
                                .frame(width: 20, height: 10)
                        case .asset(let name):
                            Image(name)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.loopedTextSecondary)
                                .frame(width: 20, height: 20)
                        }
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
    let icon: IconSource
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 20, height: 20)
            case .asset(let name):
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 20, height: 20)
            }

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

// MARK: - Settings Navigation Row

struct SettingsNavigationRow: View {
    let icon: IconSource?
    let title: String
    let textColor: Color

    init(
        icon: IconSource? = nil,
        title: String,
        textColor: Color = .loopedTextPrimary
    ) {
        self.icon = icon
        self.title = title
        self.textColor = textColor
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                switch icon {
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)
                        .frame(width: 20, height: 10)
                case .asset(let name):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(width: 20, height: 20)
                }
            }

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(textColor)
                .multilineTextAlignment(.leading)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
    }
}

// MARK: - Connected Account Row

struct ConnectedAccountRow: View {
    let icon: IconSource
    let title: String
    let buttonText: String
    let buttonColor: Color
    let isConnected: Bool

    init(
        icon: IconSource,
        title: String,
        buttonText: String,
        buttonColor: Color,
        isConnected: Bool
    ) {
        self.icon = icon
        self.title = title
        self.buttonText = buttonText
        self.buttonColor = buttonColor
        self.isConnected = isConnected
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.loopedTextPrimary)
                    .frame(width: 20, height: 20)
            case .asset(let name):
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Button(buttonText) {
                // Handle connection/disconnection
            }
            .font(.loopedSubBodyMedium)
            .foregroundColor(isConnected ? .loopedTextSecondary : .loopedSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

#Preview {
    SettingsView()
}
