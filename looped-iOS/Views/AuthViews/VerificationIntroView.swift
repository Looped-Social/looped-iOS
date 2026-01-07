import SwiftUI

struct VerificationIntroView: View {
    let loopName: String
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onContinue: () -> Void
    let onHowItWorks: () -> Void

    init(
        loopName: String = "your loop",
        currentStep: Int = 1,
        totalSteps: Int = 5,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onHowItWorks: @escaping () -> Void = {}
    ) {
        self.loopName = loopName
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onContinue = onContinue
        self.onHowItWorks = onHowItWorks
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                Spacer()
                    .frame(height: geometry.size.height * 0.04)

                Image("teal-verify")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: geometry.size.height * 0.36)
                    .padding(.horizontal, 28)

                VStack(spacing: 12) {
                    Text("Verify Your Identity\nto join \(loopName)")
                        .font(.loopedHeading)
                        .foregroundColor(.loopedContrast)
                        .multilineTextAlignment(.center)

                    Text("We require verification to post in communities\nto keep your experience authentic")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 14) {
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.loopedHeadingMedium)
                            .foregroundColor(.loopedWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.loopedBlack)
                            .clipShape(Capsule())
                    }

                    Button(action: onHowItWorks) {
                        Text("How Verification Works")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedSecondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
    }
}

private extension VerificationIntroView {
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
            }

            if totalSteps > 1 {
                VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
            }
        }
    }
}

#Preview {
    VerificationIntroView(
        loopName: "Looped",
        onBack: {},
        onContinue: {},
        onHowItWorks: {}
    )
}
