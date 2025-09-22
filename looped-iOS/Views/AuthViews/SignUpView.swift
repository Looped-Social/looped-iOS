import SwiftUI

struct SignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    let onBack: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var company = ""

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

                Text("Get Started")
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
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 24) {
                        Text("Join Your Company")
                            .font(.loopedHeading)
                            .foregroundColor(.loopedTextPrimary)
                            .multilineTextAlignment(.center)

                        VStack(spacing: 16) {
                            // Work Email field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Work Email")
                                    .font(.loopedSubBodyMedium)
                                    .foregroundColor(.loopedTextPrimary)

                                TextField("Enter your work email", text: $email)
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

                            // Username field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.loopedSubBodyMedium)
                                    .foregroundColor(.loopedTextPrimary)

                                TextField("Choose a username", text: $username)
                                    .font(.loopedBody)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                                    .autocapitalization(.none)
                            }

                            // Company field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Company")
                                    .font(.loopedSubBodyMedium)
                                    .foregroundColor(.loopedTextPrimary)

                                TextField("Enter your company name", text: $company)
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

                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.loopedSubBodyMedium)
                                    .foregroundColor(.loopedTextPrimary)

                                SecureField("Create a password", text: $password)
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

                    // Sign Up button
                    Button(action: {
                        Task {
                            await viewModel.signUp(
                                email: email,
                                password: password,
                                username: username,
                                company: company
                            )
                        }
                    }) {
                        Text("Create Account")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                (email.isEmpty || password.isEmpty || username.isEmpty || company.isEmpty || viewModel.isLoading) ?
                                Color.loopedTextSecondary.opacity(0.3) : Color.loopedPrimary
                            )
                            .cornerRadius(25)
                    }
                    .disabled(email.isEmpty || password.isEmpty || username.isEmpty || company.isEmpty || viewModel.isLoading)

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
            }
        }
    }
}

#Preview {
    SignUpView(viewModel: AuthViewModel()) { }
}