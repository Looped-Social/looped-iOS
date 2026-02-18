import SwiftUI

struct OnboardingVerificationExplainerView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let illustrationAssetName: String
    let illustrationMaxWidth: CGFloat
    let illustrationMaxHeight: CGFloat
    let onBack: (() -> Void)?
    let onContinue: () -> Void

    init(
        title: String,
        message: String,
        buttonTitle: String,
        illustrationAssetName: String = "verification-info",
        illustrationMaxWidth: CGFloat = 220,
        illustrationMaxHeight: CGFloat = 160,
        onBack: (() -> Void)? = nil,
        onContinue: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.illustrationAssetName = illustrationAssetName
        self.illustrationMaxWidth = illustrationMaxWidth
        self.illustrationMaxHeight = illustrationMaxHeight
        self.onBack = onBack
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 36)

            Image(illustrationAssetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: illustrationMaxWidth, maxHeight: illustrationMaxHeight)

            VStack(spacing: 12) {
                Text(title)
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)

            Spacer()

            PrimaryButton(title: buttonTitle, action: onContinue)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onBack != nil)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    LoopedBackButton(action: onBack)
                }
            }
        }
    }
}

#Preview {
    OnboardingVerificationExplainerView(
        title: "Verification skipped",
        message: "Finish verification in your company to join a major or field and start posting.",
        buttonTitle: "Continue",
        illustrationAssetName: "skipped-verification",
        onContinue: {}
    )
}
