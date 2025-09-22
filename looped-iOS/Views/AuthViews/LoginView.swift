import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onBack: () -> Void
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 0) {
            // Navigation header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.loopedTextPrimary)
                }

                Spacer()

                Text("Log In")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                // Invisible spacer for balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 40)

            // Main content
            VStack(spacing: 32) {
                VStack(spacing: 24) {
                    Text("Welcome Back")
                        .font(.loopedHeading)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 16) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            TextField("Enter your email", text: $email)
                                .font(.loopedBody)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(12)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            SecureField("Enter your password", text: $password)
                                .font(.loopedBody)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(12)
                        }
                    }
                }

                // Login button
                Button(action: {
                    Task {
                        await viewModel.login(email: email, password: password)
                    }
                }) {
                    Text("Log In")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            (email.isEmpty || password.isEmpty || viewModel.isLoading) ?
                            Color.loopedTextSecondary.opacity(0.3) : Color.loopedPrimary
                        )
                        .cornerRadius(25)
                }
                .disabled(email.isEmpty || password.isEmpty || viewModel.isLoading)

                // Loading and error states
                VStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel()) { }
}