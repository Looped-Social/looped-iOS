import SwiftUI

struct VerificationIntroView: View {
    let loopName: String
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: (() -> Void)?
    let onHowItWorks: () -> Void
    let showsHeader: Bool

    init(
        loopName: String = "your loop",
        currentStep: Int = 1,
        totalSteps: Int = 5,
        onBack: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onSkip: (() -> Void)? = nil,
        onHowItWorks: @escaping () -> Void = {},
        showsHeader: Bool = true
    ) {
        self.loopName = loopName
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onContinue = onContinue
        self.onSkip = onSkip
        self.onHowItWorks = onHowItWorks
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

                Spacer()
                    .frame(height: geometry.size.height * 0.04)

                Image("teal-verify")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: geometry.size.height * 0.36)
                    .padding(.horizontal, 28)

                VStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text("Verify your identity for")
                            .font(.loopedHeadingMedium28)
                            .foregroundColor(.loopedContrast)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(loopName)
                            .font(.loopedHeadingMedium28)
                            .foregroundColor(.loopedContrast)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.75)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("We require verification to post, comment, and like in communities to keep your experience authentic.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 14) {
                    PrimaryButton(title: "Continue", action: onContinue)

                    Button(action: onHowItWorks) {
                        Text("How Verification Works")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedSecondary)
                    }

	                    if currentStep > 1, let onSkip {
	                        Button(action: onSkip) {
	                            Text("Skip for now")
	                                .font(.loopedBodyMedium)
	                                .foregroundColor(.loopedTextSecondary)
	                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
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
            }
        }
    }
}

private extension VerificationIntroView {
    var header: some View {
        ZStack {
            HStack {
                LoopedBackButton(action: onBack)

                Spacer()
            }

            VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
        }
    }
}

	#Preview {
	    VerificationIntroView(
	        loopName: "Looped",
	        currentStep: 2,
	        totalSteps: 5,
	        onBack: {},
	        onContinue: {},
	        onSkip: {},
	        onHowItWorks: {}
	    )
	}
