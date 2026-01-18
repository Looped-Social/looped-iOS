import SwiftUI

struct VerificationConfirmationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    let onComplete: () -> Void
    let showsHeader: Bool

    init(
        authViewModel: AuthViewModel,
        currentStep: Int = 4,
        totalSteps: Int = 5,
        onBack: @escaping () -> Void,
        onSkip: (() -> Void)? = nil,
        onComplete: @escaping () -> Void,
        showsHeader: Bool = true
    ) {
        self.authViewModel = authViewModel
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onSkip = onSkip
        self.onComplete = onComplete
        self.showsHeader = showsHeader
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if showsHeader {
                    header
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }

                Image("logo-banner")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 68)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !showsHeader {
                ToolbarItem(placement: .principal) {
                    VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
                }

                if let onSkip {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip", action: onSkip)
                    }
                }
            }
        }
    }
}

private extension VerificationConfirmationView {
    var header: some View {
        ZStack {
            HStack {
                LoopedBackButton(action: onBack)
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
