import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct TwoFactorSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TwoFactorSettingsViewModel()
    @State private var showEnrollSheet = false
    @State private var showRemovalConfirm = false
    @State private var showReauthSheet = false
    @State private var reauthPassword = ""
    @State private var reauthError: String?
    @State private var showReauthHint = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusCard

                    if viewModel.phoneFactors.isEmpty {
                        emptyState
                    } else {
                        factorsList
                    }

                    Button(action: { showEnrollSheet = true }) {
                        Text("Add Phone")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.loopedContrast)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadFactors()
        }
        .onChange(of: viewModel.requiresReauth) { _, newValue in
            if newValue {
                showReauthSheet = viewModel.canReauthWithPassword
                showReauthHint = !viewModel.canReauthWithPassword
            }
        }
        .sheet(isPresented: $showEnrollSheet) {
            TwoFactorEnrollmentView {
                showEnrollSheet = false
                Task { await viewModel.loadFactors() }
            }
        }
        .alert("Remove this phone?", isPresented: $showRemovalConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task { await viewModel.removePendingFactor() }
            }
        } message: {
            Text("You can add it again later.")
        }
        .alert("Re-authentication required", isPresented: $showReauthHint) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please sign out and sign back in to manage two-factor authentication.")
        }
        .sheet(isPresented: $showReauthSheet) {
            PasswordReauthView(
                password: $reauthPassword,
                errorMessage: reauthError,
                onCancel: {
                    showReauthSheet = false
                    reauthPassword = ""
                },
                onConfirm: {
                    Task {
                        let success = await viewModel.reauthenticateWithPassword(reauthPassword)
                        if success {
                            reauthPassword = ""
                            showReauthSheet = false
                            await viewModel.removePendingFactor()
                        } else {
                            reauthError = viewModel.errorMessage
                        }
                    }
                }
            )
        }
    }
}

private extension TwoFactorSettingsView {
    var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            Text("Two-Factor Authentication")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Image(systemName: "chevron.left")
                .font(.system(size: 24, weight: .medium))
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }

    var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            Text(viewModel.isEnabled ? "Enabled" : "Off")
                .font(.loopedHeadingMedium)
                .foregroundColor(viewModel.isEnabled ? .loopedSecondary : .loopedTextPrimary)

            Text("Add a phone number for extra security when signing in.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 8)
    }

    var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No phones added")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
            Text("Add a phone number to enable two-factor authentication.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.loopedTextSecondary.opacity(0.05))
        .cornerRadius(12)
    }

    var factorsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.phoneFactors) { factor in
                HStack(spacing: 12) {
                    Image(systemName: "phone")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.loopedSecondary)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(factor.displayName)
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)

                        Text(masked(phone: factor.phoneNumber))
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    Spacer()

                    Button("Remove") {
                        viewModel.pendingRemoval = factor
                        showRemovalConfirm = true
                    }
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if factor.id != viewModel.phoneFactors.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .background(Color.loopedTextSecondary.opacity(0.05))
        .cornerRadius(12)
    }

    func masked(phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        guard digits.count >= 4 else { return phone }
        let suffix = digits.suffix(4)
        return "••• ••• \(suffix)"
    }
}

private struct TwoFactorEnrollmentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TwoFactorEnrollmentViewModel()
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text("Add Phone")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 16) {
                if viewModel.step == .phoneEntry {
                    Text("Enter your phone number")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    TextField("+1 555 123 4567", text: $viewModel.phoneNumber)
                        .font(.loopedBody)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.loopedMutedBackground.opacity(0.6))
                        .cornerRadius(12)
                        .keyboardType(.phonePad)

                    Button(action: {
                        Task { await viewModel.sendCode() }
                    }) {
                        Text(viewModel.isLoading ? "Sending..." : "Send Code")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.loopedContrast)
                            .clipShape(Capsule())
                    }
                    .disabled(viewModel.isLoading)
                } else {
                    Text("Enter the code we sent")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    TextField("Verification code", text: $viewModel.verificationCode)
                        .font(.loopedBody)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.loopedMutedBackground.opacity(0.6))
                        .cornerRadius(12)
                        .keyboardType(.numberPad)

                    Button(action: {
                        Task {
                            let success = await viewModel.enroll()
                            if success {
                                onComplete()
                            }
                        }
                    }) {
                        Text(viewModel.isLoading ? "Verifying..." : "Verify & Add")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.loopedContrast)
                            .clipShape(Capsule())
                    }
                    .disabled(viewModel.isLoading)

                    Button(action: {
                        Task { await viewModel.resendCode() }
                    }) {
                        Text("Resend code")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedSecondary)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.loopedBackground.ignoresSafeArea())
    }
}

private struct PasswordReauthView: View {
    @Binding var password: String
    let errorMessage: String?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Confirm Password")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            SecureField("Password", text: $password)
                .font(.loopedBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)

            if let errorMessage {
                Text(errorMessage)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.loopedMutedBackground)
                    .clipShape(Capsule())

                Button("Continue", action: onConfirm)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.loopedContrast)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .presentationDetents([.medium])
    }
}

#Preview {
    TwoFactorSettingsView()
}
