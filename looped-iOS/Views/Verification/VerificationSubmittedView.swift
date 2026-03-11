import SwiftUI

struct VerificationSubmittedView: View {
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onComplete: () -> Void
    let showsHeader: Bool

    init(
        currentStep: Int,
        totalSteps: Int,
        onBack: @escaping () -> Void,
        onComplete: @escaping () -> Void,
        showsHeader: Bool = true
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
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
                    .frame(maxHeight: geometry.size.height * 0.414)
                    .padding(.horizontal, 28)

                VStack(spacing: 10) {
                    Text("Thanks for submitting!")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text("We’ll review your verification in the next few days.\nYou’ll get access once it’s approved.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)

                Spacer()

                PrimaryButton(title: "Done", action: onComplete)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !showsHeader {
                ToolbarItem(placement: .principal) {
                    VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
                }
            }
        }
    }
}

private extension VerificationSubmittedView {
    var header: some View {
        ZStack {
            HStack {
                Color.loopedClear
                    .frame(width: 44, height: 44)
                Spacer()
            }

            VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
        }
    }
}

#Preview {
    VerificationSubmittedView(
        currentStep: 4,
        totalSteps: 4,
        onBack: {},
        onComplete: {}
    )
}
