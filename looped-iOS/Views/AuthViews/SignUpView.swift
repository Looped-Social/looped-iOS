import SwiftUI

struct SignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onBack: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var didAttemptSubmit = false

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.loopedCustom(.medium, size: 18))
                            .foregroundColor(.loopedTextPrimary)
                            .padding(10)
                            .background(Color.loopedMutedBackground)
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

                        Text("Use your work email. You'll finish setting up your profile next.")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 16) {
                            inputField(title: "Work Email", placeholder: "you@company.com", text: $email, keyboard: .emailAddress)
                            passwordField(title: "Password", placeholder: "Create a password", text: $password)
                        }
                        .padding()
                        .background(Color.loopedBackground)
                        .cornerRadius(18)
                        .shadow(color: Color.loopedBlack.opacity(0.05), radius: 12, x: 0, y: 8)

                        PasswordRequirementsView(
                            requirements: passwordRequirements,
                            showMissingOnly: !password.isEmpty
                        )
                        .padding(.horizontal, 12)

                        Button(action: {
                            Task {
                                didAttemptSubmit = true
                                await viewModel.signUp(
                                    email: email,
                                    password: password
                                )
                            }
                        }) {
                            Text("Create Account")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                (email.isEmpty || password.isEmpty || !isPasswordValid || viewModel.isLoading) ?
                                    Color.loopedTextSecondary.opacity(0.3) : Color.loopedPrimary
                                )
                                .cornerRadius(14)
                        }
                        .disabled(email.isEmpty || password.isEmpty || !isPasswordValid || viewModel.isLoading)

                        if didAttemptSubmit, !isPasswordValid {
                            Text("Password must meet all requirements.")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedError)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        } else if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedError)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .loadingOverlay(isPresented: viewModel.isLoading, title: "Creating your account…")
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            TextField(placeholder, text: text)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)
                .tint(.loopedPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.none)
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
                .textContentType(.newPassword)
                .foregroundColor(.loopedTextPrimary)
                .tint(.loopedPrimary)
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

    private var passwordRequirements: [PasswordRequirement] {
        [
            PasswordRequirement(
                title: "At least 8 characters",
                isMet: password.count >= 8
            ),
            PasswordRequirement(
                title: "One uppercase letter",
                isMet: password.rangeOfCharacter(from: .uppercaseLetters) != nil
            ),
            PasswordRequirement(
                title: "One number",
                isMet: password.rangeOfCharacter(from: .decimalDigits) != nil
            ),
            PasswordRequirement(
                title: "One special character",
                isMet: password.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil
            )
        ]
    }

    private var isPasswordValid: Bool {
        passwordRequirements.allSatisfy { $0.isMet }
    }
}

#Preview {
    SignUpView(viewModel: AuthViewModel()) { }
}

private struct PasswordRequirement: Identifiable {
    let id = UUID()
    let title: String
    let isMet: Bool
}

private struct PasswordRequirementsView: View {
    let requirements: [PasswordRequirement]
    let showMissingOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(requirements) { requirement in
                if !showMissingOnly || !requirement.isMet {
                    HStack(spacing: 8) {
                        Image(systemName: requirement.isMet ? "checkmark.circle" : "circle")
                            .font(.loopedCustom(.medium, size: 12))
                            .foregroundColor(requirement.isMet ? .loopedSecondary : .loopedTextSecondary.opacity(0.6))

                        Text(requirement.title)
                            .font(.loopedSmallText)
                            .foregroundColor(requirement.isMet ? .loopedTextPrimary : .loopedTextSecondary)
                    }
                }
            }
        }
        .padding(.top, 2)
    }
}
