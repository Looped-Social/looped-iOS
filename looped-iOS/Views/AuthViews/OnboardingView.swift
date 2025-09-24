import SwiftUI

struct OnboardingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onNavigate: (AuthScreen) -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                    .frame(height: geometry.size.height * 0.20)

                // Logo and tagline
                VStack(spacing: 16) {
                    // Looped logo (larger for onboarding)
                    HStack(spacing: 2) {
                        Image("logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 68)

                        Text("ooped")
                            .font(.loopedSuperLargeHeading)
                            .foregroundColor(.loopedTextPrimary)
                    }

                    // Tagline
                    VStack(spacing: 4) {
                        Text("Where Verified Voices")
                            .font(.loopedHeadingMedium)
                            .foregroundColor(.loopedTextPrimary)
                        Text("speak freely")
                            .font(.loopedHeadingMedium)
                            .foregroundColor(.loopedTextPrimary)
                    }
                }
                .padding(.bottom, 32)

                // Buttons section
                VStack(spacing: 12) {
                    // Get Started button
                    Button(action: {
                        onNavigate(.employmentStatus)
                    }) {
                        Text("Get Started")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.loopedPrimary)
                            .cornerRadius(25)
                    }

                    // "or" divider
                    Text("or")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.vertical, 8)

                    // Continue with Google button
                    Button(action: {
                        Task {
                            // Mock Google login
                            await authViewModel.login(email: "user@company.com", password: "password")
                        }
                    }) {
                        HStack {
                            // Google logo placeholder (using "G" for now)
                            Image("google-logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 24)

                            Text("Continue with Google")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(25)
                    }
                    .disabled(authViewModel.isLoading)

                    // Continue with Apple button
                    Button(action: {
                        Task {
                            // Mock Apple login
                            await authViewModel.login(email: "user@company.com", password: "password")
                        }
                    }) {
                        HStack {
                            // Apple logo placeholder (using apple symbol)
                            Image(systemName: "applelogo")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.loopedTextPrimary)

                            Text("Continue with Apple")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(25)
                    }
                    .disabled(authViewModel.isLoading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

                // Already have account link
                VStack(spacing: 8) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                    }

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    HStack {
                        Text("Already have an Account?")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)

                        Button("Log in") {
                            onNavigate(.login)
                        }
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedSecondary)
                    }
                }
                .padding(.bottom,32)
            }
        }
    }
}

#Preview {
    OnboardingView(authViewModel: AuthViewModel()) { _ in }
}
