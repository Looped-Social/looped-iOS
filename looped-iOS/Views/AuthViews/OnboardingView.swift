import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onNavigate: (AuthScreen) -> Void
    @Environment(\.colorScheme) private var colorScheme

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

                    // Continue with Google button (custom styling)
                    Button(action: { Task { await authViewModel.signInWithGoogle() } }) {
                        HStack(spacing: 12) {
                            Image("google-logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)

                            Text("Continue with Google")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.9 : 1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(25)
                    }
                    .disabled(authViewModel.isLoading)

                    // Continue with Apple button (auto style per mode)
                    SignInWithAppleButton(.signIn) { request in
                        authViewModel.configureAppleRequest(request)
                    } onCompletion: { result in
                        Task { await authViewModel.handleAppleCompletion(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .black : .white)
                    .frame(height: 50)
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                    )
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
