import SwiftUI

#if canImport(FirebaseAuth)
import FirebaseAuth

struct TwoFactorChallengeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let session: MFAChallengeSession

    @Environment(\.dismiss) private var dismiss
    @State private var selectedHintId: String?
    @State private var verificationId: String?
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Two-factor authentication")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text("We sent a code to your phone. Enter it below to finish signing in.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)

                    if session.phoneHints.count > 1 {
                        hintList
                    } else if let hint = selectedHint, !hint.phoneNumber.isEmpty {
                        Text("Using \(masked(phone: hint.phoneNumber))")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    if verificationId == nil {
                        Button(action: sendCode) {
                            Text(isLoading ? "Sending..." : "Send Code")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.loopedContrast)
                                .clipShape(Capsule())
                        }
                        .disabled(isLoading || selectedHintId == nil)
                    } else {
                        TextField("Verification code", text: $code)
                            .font(.loopedBody)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground.opacity(0.6))
                            .cornerRadius(12)
                            .keyboardType(.numberPad)

                        Button(action: verifyCode) {
                            Text(isLoading ? "Verifying..." : "Verify")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.loopedContrast)
                                .clipShape(Capsule())
                        }
                        .disabled(isLoading || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button(action: sendCode) {
                            Text("Resend code")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedSecondary)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .onAppear {
            selectedHintId = session.phoneHints.first?.uid
            if session.phoneHints.count == 1 {
                sendCode()
            }
        }
    }
}

private extension TwoFactorChallengeView {
    var header: some View {
        HStack {
            Button(action: handleCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            Text("Two-Factor")
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
    }

    var hintList: some View {
        VStack(spacing: 0) {
            ForEach(session.phoneHints, id: \.uid) { hint in
                Button(action: { selectedHintId = hint.uid }) {
                    HStack {
                        Text(masked(phone: hint.phoneNumber ?? ""))
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)

                        Spacer()

                        Image(systemName: selectedHintId == hint.uid ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedHintId == hint.uid ? .loopedSecondary : .loopedTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())

                if hint.uid != session.phoneHints.last?.uid {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .background(Color.loopedTextSecondary.opacity(0.05))
        .cornerRadius(12)
    }

    var selectedHint: PhoneMultiFactorInfo? {
        guard let selectedHintId else { return nil }
        return session.phoneHints.first(where: { $0.uid == selectedHintId })
    }

    func sendCode() {
        guard let hintId = selectedHintId else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let id = try await authViewModel.sendMfaCode(session: session, hintId: hintId)
                verificationId = id
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func verifyCode() {
        guard let verificationId else { return }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                try await authViewModel.resolveMfaSignIn(
                    session: session,
                    verificationId: verificationId,
                    code: trimmed
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func masked(phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        guard digits.count >= 4 else { return phone }
        let suffix = digits.suffix(4)
        return "••• ••• \(suffix)"
    }

    func handleCancel() {
        authViewModel.dismissMfa()
        dismiss()
    }
}

#endif
