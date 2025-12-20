import SwiftUI

struct WaysToVerifyView: View {
    let options: [VerificationOption]
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onContinue: (VerificationOption) -> Void
    let onSkip: () -> Void
    let onLearnMore: () -> Void

    @State private var selectedOption: VerificationOption?

    init(
        options: [VerificationOption] = [
            VerificationOption(id: "photo_id", title: "Photo With Gov. ID"),
            VerificationOption(id: "company_email", title: "Company Email")
        ],
        currentStep: Int = 2,
        totalSteps: Int = 5,
        onBack: @escaping () -> Void,
        onContinue: @escaping (VerificationOption) -> Void,
        onSkip: @escaping () -> Void,
        onLearnMore: @escaping () -> Void = {}
    ) {
        self.options = options
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onContinue = onContinue
        self.onSkip = onSkip
        self.onLearnMore = onLearnMore
        _selectedOption = State(initialValue: options.first)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                Spacer()
                    .frame(height: geometry.size.height * 0.12)

                Text("Ways To Verify")
                    .font(.loopedHeading)
                    .foregroundColor(.loopedContrast)

                Spacer()

                VStack(spacing: 12) {
                    ForEach(options) { option in
                        VerificationOptionButton(
                            title: option.title,
                            isSelected: option == selectedOption
                        ) {
                            selectedOption = option
                        }
                    }
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("Your information is never stored")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)

                    Button(action: onLearnMore) {
                        Text("learn more here")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedSecondary)
                    }
                }

                Button(action: handleContinue) {
                    Text("Continue")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.loopedContrast)
                        .clipShape(Capsule())
                }
                .padding(.top, 16)
                .padding(.horizontal, 32)

                Button(action: onSkip) {
                    Text("Skip For now")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedSecondary)
                }
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
    }
}

struct VerificationOption: Identifiable, Equatable {
    let id: String
    let title: String
}

private extension WaysToVerifyView {
    var header: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
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

    func handleContinue() {
        guard let selectedOption else { return }
        onContinue(selectedOption)
    }
}

private struct VerificationOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.loopedBody)
                .foregroundColor(.loopedContrast)
                .frame(maxWidth: 260)
                .frame(height: 44)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            isSelected ? Color.loopedContrast : Color.loopedTextSecondary.opacity(0.3),
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    WaysToVerifyView(
        onBack: {},
        onContinue: { _ in },
        onSkip: {},
        onLearnMore: {}
    )
}
