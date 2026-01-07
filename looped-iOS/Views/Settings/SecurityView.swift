import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct SecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var biometricLoginEnabled = true
    @State private var loginNotifications = true
    @State private var showResetPasswordSheet = false
    @State private var twoFactorStatusText = "Off"

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

                Text("Security")
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
                    // Authentication Section
                    SecuritySection(title: "Authentication") {
                        NavigationLink(destination: TwoFactorSettingsView()) {
                            SecurityNavigationRow(
                                icon: "lock.shield",
                                title: "Two-Factor Authentication",
                                subtitle: twoFactorStatusText
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

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
        .onAppear {
            refreshTwoFactorStatus()
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

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color.loopedSecondary))
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

struct SecurityNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
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
}

private extension SecurityView {
    var currentEmail: String {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.email ?? ""
        #else
        return ""
        #endif
    }

    func refreshTwoFactorStatus() {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            twoFactorStatusText = "Off"
            return
        }
        let count = user.multiFactor.enrolledFactors.count
        twoFactorStatusText = count > 0 ? "Enabled" : "Off"
        #else
        twoFactorStatusText = "Unavailable"
        #endif
    }
}

#Preview {
    SecurityView()
        .environmentObject(AuthViewModel())
}
