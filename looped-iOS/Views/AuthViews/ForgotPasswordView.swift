import SwiftUI

struct ForgotPasswordView: View {
    let initialEmail: String
    let onDismiss: () -> Void
    let sendResetLink: (String) async throws -> Void

    @State private var email: String
    @State private var isSubmitting = false
    @State private var didSend = false
    @State private var errorMessage: String?
    @FocusState private var isEmailFocused: Bool

    init(
        initialEmail: String = "",
        onDismiss: @escaping () -> Void,
        sendResetLink: @escaping (String) async throws -> Void
    ) {
        self.initialEmail = initialEmail
        self.onDismiss = onDismiss
        self.sendResetLink = sendResetLink
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    LoopedCloseButton(action: onDismiss)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                VStack(spacing: 18) {
                    Text("Reset your password")
                        .font(.loopedHeadingMedium32)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Enter your email and we’ll send a link to reset your password.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 16) {
                        inputField(title: "Email", placeholder: "you@example.com", text: $email)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedError)
                                .multilineTextAlignment(.center)
                        }

                        if didSend {
                            Text("If an account exists for that email, you’ll receive a reset link shortly.")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color.loopedBackground)
                    .cornerRadius(18)
                    .shadow(color: Color.loopedBlack.opacity(0.05), radius: 12, x: 0, y: 8)

                    Button(action: submit) {
                        Text(didSend ? "Resend Link" : "Send Reset Link")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                (email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting) ?
                                Color.loopedTextSecondary.opacity(0.3) : Color.loopedPrimary
                            )
                            .cornerRadius(14)
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

                    if isSubmitting {
                        ProgressView()
                            .tint(.loopedPrimary)
                    }

                    Button("Back to login") {
                        onDismiss()
                    }
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedSecondary)
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .onAppear {
            if email.isEmpty {
                isEmailFocused = true
            }
        }
    }

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }

        errorMessage = nil

        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await sendResetLink(trimmedEmail)
                didSend = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            TextField(placeholder, text: text)
                .focused($isEmailFocused)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)
                .tint(.loopedPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
        }
    }
}

#Preview {
    ForgotPasswordView(
        initialEmail: "you@example.com",
        onDismiss: { },
        sendResetLink: { _ in }
    )
}
