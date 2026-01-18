import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct SecurityView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var biometricLoginEnabled = true
    @State private var loginNotifications = true
    @State private var showResetPasswordSheet = false

    var body: some View {
        List {
            Section("Authentication") {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showResetPasswordSheet = true
                } label: {
                    HStack(spacing: 12) {
                        SettingsRowLabel(
                            icon: .system("key"),
                            title: "Reset Password",
                            subtitle: "Send a reset link to your email"
                        )
                        Image(systemName: "chevron.right")
                            .font(.loopedCustom(.semibold, size: 14))
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Login Activity") {
                Toggle(isOn: $loginNotifications) {
                    SettingsRowLabel(
                        icon: .system("bell.badge"),
                        title: "Login Notifications",
                        subtitle: "Get notified of new logins"
                    )
                }
                .tint(.loopedSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
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
