import SwiftUI

struct SignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onBack: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.loopedTextPrimary)
                            .padding(10)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                ScrollView {
                    VStack(spacing: 20) {
                        Text("Create your Looped account")
                            .font(.loopedHeading)
                            .foregroundColor(.loopedTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Use your work email. You can set company and profile details later.")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 16) {
                            inputField(title: "Work Email", placeholder: "you@company.com", text: $email, keyboard: .emailAddress)
                            inputField(title: "Username", placeholder: "looped handle", text: $username, keyboard: .default)
                            secureField(title: "Password", placeholder: "Create a password", text: $password)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)

                        Button(action: {
                            Task {
                                await viewModel.signUp(
                                    email: email,
                                    password: password,
                                    username: username
                                )
                            }
                        }) {
                            Text("Create Account")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    (email.isEmpty || password.isEmpty || username.isEmpty || viewModel.isLoading) ?
                                    Color.loopedTextSecondary.opacity(0.3) : Color.loopedPrimary
                                )
                                .cornerRadius(14)
                        }
                        .disabled(email.isEmpty || password.isEmpty || username.isEmpty || viewModel.isLoading)

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
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            TextField(placeholder, text: text)
                .font(.loopedBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.none)
        }
    }

    private func secureField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            SecureField(placeholder, text: text)
                .font(.loopedBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)
        }
    }
}

#Preview {
    SignUpView(viewModel: AuthViewModel()) { }
}
