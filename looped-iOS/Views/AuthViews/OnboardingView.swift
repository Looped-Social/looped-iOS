import SwiftUI

struct OnboardingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onNavigate: (AuthScreen) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryButtonFont = Font.loopedCustom(.semibold, size: 17)
        let socialButtonFont = Font.loopedCustom(.medium, size: 17)
        let socialButtonTextColor = Color.loopedContrast
        let socialButtonBorderColor = colorScheme == .dark
            ? Color.loopedContrast.opacity(0.85)
            : Color.loopedTextSecondary.opacity(0.3)

        GeometryReader { geometry in
            ZStack {
                VStack {
                Spacer()
                    .frame(height: geometry.size.height * 0.15)

                // Logo
                VStack(spacing: 16) {
                    Image("logo-banner-modo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 164)
                        .accessibilityLabel("Looped Connect Diffrently")
                }
                .padding(.bottom, 24)

                // Buttons section
                VStack(spacing: 12) {
                    // Get Started button
                    Button(action: {
                        authViewModel.errorMessage = nil
                        onNavigate(.signUp)
                    }) {
                        Text("Get Started")
                            .font(primaryButtonFont)
                            .foregroundColor(.loopedWhite)
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
                    Button(action: {
                        Task { await authViewModel.signInWithGoogle() }
                    }) {
                        socialButtonLabel(
                            iconAssetName: "google-logo",
                            title: "Continue with Google",
                            font: socialButtonFont,
                            textColor: socialButtonTextColor,
                            borderColor: socialButtonBorderColor
                        )
                    }
                    .disabled(authViewModel.isLoading)

                    // Continue with Apple button (custom to match Google sizing/typography)
                    Button(action: {
                        Task { await authViewModel.signInWithApple() }
                    }) {
                        socialButtonLabel(
                            iconAssetName: "apple-logo",
                            title: "Continue with Apple",
                            font: socialButtonFont,
                            textColor: socialButtonTextColor,
                            borderColor: socialButtonBorderColor
                        )
                    }
                    .disabled(authViewModel.isLoading)
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 0)

                // Already have account link
                VStack(spacing: 8) {
                    HStack {
                        Text("Already have an Account?")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)

                        Button("Log in") {
                            authViewModel.errorMessage = nil
                            onNavigate(.login)
                        }
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedSecondary)
                    }
                }
                .padding(.bottom, max(8, geometry.safeAreaInsets.bottom + 4))
                }

                if authViewModel.isLoading {
                    LoopedLoadingOverlay(title: "Signing you in…")
                }
            }
        }
    }

    @ViewBuilder
    private func socialButtonLabel(
        iconAssetName: String,
        title: String,
        font: Font,
        textColor: Color,
        borderColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(iconAssetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

            Text(title)
                .font(font)
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.loopedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(borderColor, lineWidth: 1)
        )
        .cornerRadius(25)
    }
}

#Preview {
    OnboardingView(authViewModel: AuthViewModel()) { _ in }
}
