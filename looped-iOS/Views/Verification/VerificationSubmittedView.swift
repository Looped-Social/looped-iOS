import SwiftUI

struct VerificationSubmittedView: View {
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onComplete: () -> Void

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
    }
}

private extension VerificationSubmittedView {
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

