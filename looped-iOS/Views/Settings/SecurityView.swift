import SwiftUI

struct SecurityView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var twoFactorEnabled = false
    @State private var biometricLoginEnabled = true
    @State private var loginNotifications = true
    @State private var showChangePasswordSheet = false

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

                Text("Security")
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
                    // Authentication Section
                    SecuritySection(title: "Authentication") {
                        SecurityToggleRow(
                            icon: "lock.shield",
                            title: "Two-Factor Authentication",
                            subtitle: "Add an extra layer of security",
                            isOn: $twoFactorEnabled
                        )

                        SecurityToggleRow(
                            icon: "faceid",
                            title: "Biometric Login",
                            subtitle: "Use Face ID or Touch ID",
                            isOn: $biometricLoginEnabled
                        )

                        SecurityActionRow(
                            icon: "key",
                            title: "Change Password",
                            subtitle: "Update your account password"
                        ) {
                            showChangePasswordSheet = true
                        }
                    }

                    // Login Activity Section
                    SecuritySection(title: "Login Activity") {
                        SecurityToggleRow(
                            icon: "bell.badge",
                            title: "Login Notifications",
                            subtitle: "Get notified of new logins",
                            isOn: $loginNotifications
                        )

                        SecurityActionRow(
                            icon: "clock.arrow.circlepath",
                            title: "Active Sessions",
                            subtitle: "Manage your active sessions"
                        ) {
                            // TODO: Navigate to active sessions
                        }

                        SecurityActionRow(
                            icon: "list.bullet.clipboard",
                            title: "Login History",
                            subtitle: "View recent login activity"
                        ) {
                            // TODO: Navigate to login history
                        }
                    }

                    // Account Recovery Section
                    SecuritySection(title: "Account Recovery") {
                        SecurityActionRow(
                            icon: "envelope",
                            title: "Recovery Email",
                            subtitle: "john.doe@example.com"
                        ) {
                            // TODO: Change recovery email
                        }

                        SecurityActionRow(
                            icon: "phone",
                            title: "Recovery Phone",
                            subtitle: "Add a recovery phone number"
                        ) {
                            // TODO: Add recovery phone
                        }
                    }

                    // Privacy Section
                    SecuritySection(title: "Privacy") {
                        SecurityActionRow(
                            icon: "eye.slash",
                            title: "Blocked Accounts",
                            subtitle: "Manage blocked users"
                        ) {
                            // TODO: Navigate to blocked accounts
                        }

                        SecurityActionRow(
                            icon: "hand.raised",
                            title: "Data & Privacy",
                            subtitle: "Download or delete your data"
                        ) {
                            // TODO: Navigate to data & privacy
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showChangePasswordSheet) {
            ChangePasswordView()
        }
    }
}

// MARK: - Security Section

struct SecuritySection<Content: View>: View {
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

// MARK: - Security Toggle Row

struct SecurityToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
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

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.4, green: 0.7, blue: 0.6)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Security Action Row

struct SecurityActionRow: View {
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

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Password")
                        .font(.loopedBodyStrong)
                        .foregroundColor(.loopedTextPrimary)

                    SecureField("Enter current password", text: $currentPassword)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(12)
                        .background(Color.loopedTextSecondary.opacity(0.1))
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("New Password")
                        .font(.loopedBodyStrong)
                        .foregroundColor(.loopedTextPrimary)

                    SecureField("Enter new password", text: $newPassword)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(12)
                        .background(Color.loopedTextSecondary.opacity(0.1))
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm New Password")
                        .font(.loopedBodyStrong)
                        .foregroundColor(.loopedTextPrimary)

                    SecureField("Confirm new password", text: $confirmPassword)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(12)
                        .background(Color.loopedTextSecondary.opacity(0.1))
                        .cornerRadius(8)
                }

                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    // TODO: Implement password change
                    dismiss()
                }) {
                    Text("Change Password")
                        .font(.loopedBodyStrong)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.loopedPrimary)
                        .cornerRadius(12)
                }
                .padding(.top, 20)

                Spacer()
            }
            .padding(20)
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.loopedTextSecondary)
                }
            }
        }
    }
}

#Preview {
    SecurityView()
}
