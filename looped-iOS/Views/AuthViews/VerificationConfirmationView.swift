import SwiftUI

struct VerificationConfirmationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    let onComplete: () -> Void

    init(
        authViewModel: AuthViewModel,
        currentStep: Int = 4,
        totalSteps: Int = 5,
        onBack: @escaping () -> Void,
        onSkip: (() -> Void)? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.authViewModel = authViewModel
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onSkip = onSkip
        self.onComplete = onComplete
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                HStack(spacing: 2) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 68)

                    Text("ooped")
                        .font(.loopedSuperLargeHeading)
                        .foregroundColor(.loopedTextPrimary)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)

                Image("confirm-verify")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: geometry.size.height * 0.36)
                    .padding(.horizontal, 28)

                VStack(spacing: 10) {
                    Text("Thanks for submitting!")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text("Give us 24 Hours to process your verification,\nyou're on your way to your first loop!")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)

                Spacer()

                PrimaryButton(
                    title: "Continue",
                    isEnabled: !authViewModel.isLoading,
                    isLoading: authViewModel.isLoading,
                    action: onComplete
                )
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
    }
}

private extension VerificationConfirmationView {
    var header: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.loopedCustom(.semibold, size: 20))
                        .foregroundColor(.loopedTextPrimary)
                        .frame(width: 40, height: 40)
                }
                Spacer()

                if let onSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedSecondary)
                    }
                    .padding(.trailing, 4)
                }
            }

            VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
        }
    }
}

#Preview {
    VerificationConfirmationView(authViewModel: AuthViewModel(), onBack: { }, onSkip: { }, onComplete: { })
}
