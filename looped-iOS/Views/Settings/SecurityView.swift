import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct SecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var twoFactorEnabled = false
    @State private var biometricLoginEnabled = true
    @State private var loginNotifications = true
    @State private var showResetPasswordSheet = false

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
                            title: "Reset Password",
                            subtitle: "Send a reset link to your email"
                        ) {
                            showResetPasswordSheet = true
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
        .sheet(isPresented: $showResetPasswordSheet) {
            ForgotPasswordView(
                initialEmail: currentEmail,
                onDismiss: { showResetPasswordSheet = false },
                sendResetLink: { email in
                    try await authViewModel.sendPasswordReset(email: email)
                }
            )
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

private extension SecurityView {
    var currentEmail: String {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.email ?? ""
        #else
        return ""
        #endif
    }
}

#Preview {
    SecurityView()
        .environmentObject(AuthViewModel())
}
