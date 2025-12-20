import SwiftUI

struct VerificationConfirmationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let currentStep: Int
    let totalSteps: Int
    let onComplete: () -> Void

    init(
        authViewModel: AuthViewModel,
        currentStep: Int = 4,
        totalSteps: Int = 5,
        onComplete: @escaping () -> Void
    ) {
        self.authViewModel = authViewModel
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onComplete = onComplete
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.top, 8)

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

                Button(action: onComplete) {
                    Text("Continue")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
                .disabled(authViewModel.isLoading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
    }
}

#Preview {
    VerificationConfirmationView(authViewModel: AuthViewModel(), onComplete: { })
}
