import SwiftUI

struct VerificationConfirmationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    let onComplete: () -> Void
    let showsHeader: Bool
    let confirmationKind: ConfirmationKind

    enum ConfirmationKind: Equatable {
        case photoIdPending
        case emailVerified(loopName: String)
    }

    init(
        authViewModel: AuthViewModel,
        currentStep: Int = 4,
        totalSteps: Int = 5,
        onBack: @escaping () -> Void,
        onSkip: (() -> Void)? = nil,
        onComplete: @escaping () -> Void,
        showsHeader: Bool = true,
        confirmationKind: ConfirmationKind = .photoIdPending
    ) {
        self.authViewModel = authViewModel
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onSkip = onSkip
        self.onComplete = onComplete
        self.showsHeader = showsHeader
        self.confirmationKind = confirmationKind
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
                    Text(titleText)
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(subtitleText)
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

    var titleText: String {
        switch confirmationKind {
        case .photoIdPending:
            return "Thanks for submitting!"
        case .emailVerified:
            return "You’re verified!"
        }
    }

    var subtitleText: String {
        switch confirmationKind {
        case .photoIdPending:
            return "Give us 24 Hours to process your verification,\nyou're on your way to your first loop!"
        case .emailVerified(let loopName):
            return "You’re verified for \(loopName).\nFollow the rules and have fun."
        }
    }
}

#Preview {
    VerificationConfirmationView(
        authViewModel: AuthViewModel(),
        onBack: { },
        onSkip: { },
        onComplete: { },
        confirmationKind: .emailVerified(loopName: "Looped")
    )
}
