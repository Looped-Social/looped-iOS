import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onBack: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isForgotPasswordPresented = false

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation/header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.loopedTextPrimary)
                            .padding(10)
                            .background(Color.loopedMutedBackground)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer().frame(height: 12)

                VStack(spacing: 18) {
                    Text("Welcome back")
                        .font(.loopedHeading)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Sign in with your work email or continue with Google/Apple.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 16) {
                        inputField(title: "Email", placeholder: "you@company.com", text: $email, isSecure: false, keyboard: .emailAddress)
                        passwordField(title: "Password", placeholder: "Enter your password", text: $password)

                        HStack {
                            Spacer()
                            Button("Forgot password?") {
                                isForgotPasswordPresented = true
                            }
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedSecondary)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color.loopedBackground)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)

                    Button(action: {
                        Task { await viewModel.login(email: email, password: password) }
                    }) {
                        Text("Log In")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                (email.isEmpty || password.isEmpty || viewModel.isLoading) ?
                                Color.loopedTextSecondary.opacity(0.3) : Color.loopedPrimary
                            )
                            .cornerRadius(14)
                    }
                    .disabled(email.isEmpty || password.isEmpty || viewModel.isLoading)

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.loopedPrimary)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .sheet(isPresented: $isForgotPasswordPresented) {
            ForgotPasswordView(
                initialEmail: email,
                onDismiss: { isForgotPasswordPresented = false },
                sendResetLink: { email in
                    try await viewModel.sendPasswordReset(email: email)
                }
            )
        }
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>, isSecure: Bool, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.none)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                }
            }
            .font(.loopedBody)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.loopedMutedBackground.opacity(0.6))
            .cornerRadius(12)
        }
    }

    private func passwordField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            HStack(spacing: 12) {
                Group {
                    if isPasswordVisible {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled()
                .textContentType(.password)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(isPasswordVisible ? "Hide" : "Show") {
                    isPasswordVisible.toggle()
                }
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedSecondary)
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }
            .font(.loopedBody)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.loopedMutedBackground.opacity(0.6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel()) { }
}
