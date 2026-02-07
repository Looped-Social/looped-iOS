import SwiftUI

struct WaysToVerifyView: View {
    let options: [VerificationOption]
    let currentStep: Int
    let totalSteps: Int
    @Binding var selectedOptionId: String?
    let onBack: () -> Void
    let onContinue: (VerificationOption) -> Void
    let onSkip: (() -> Void)?
    let onLearnMore: () -> Void
    let showsHeader: Bool

    init(
        options: [VerificationOption] = [
            VerificationOption(id: "company_email", title: "Company Email"),
            VerificationOption(id: "photo_id", title: "Work ID / Work Badge")
        ],
        currentStep: Int = 2,
        totalSteps: Int = 5,
        selectedOptionId: Binding<String?> = .constant(nil),
        onBack: @escaping () -> Void,
        onContinue: @escaping (VerificationOption) -> Void,
        onSkip: (() -> Void)?,
        onLearnMore: @escaping () -> Void = {},
        showsHeader: Bool = true
    ) {
        self.options = options
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self._selectedOptionId = selectedOptionId
        self.onBack = onBack
        self.onContinue = onContinue
        self.onSkip = onSkip
        self.onLearnMore = onLearnMore
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
                    .frame(height: geometry.size.height * 0.12)

                Text("Ways To Verify")
                    .font(.loopedHeading)
                    .foregroundColor(.loopedContrast)

                Spacer()

                VStack(spacing: 12) {
                    ForEach(options) { option in
                        VerificationOptionButton(
                            title: option.title,
                            isSelected: option.id == resolvedSelectedOption?.id
                        ) {
                            selectedOptionId = option.id
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

                PrimaryButton(title: "Continue", action: handleContinue)
                .padding(.top, 16)
                .padding(.horizontal, 32)

                if let onSkip {
                    Button(action: onSkip) {
                        Text("Skip For now")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedSecondary)
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                } else {
                    Spacer()
                        .frame(height: 20)
                }
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

struct VerificationOption: Identifiable, Equatable {
    let id: String
    let title: String
}

private extension WaysToVerifyView {
    var header: some View {
        ZStack {
            HStack {
                LoopedBackButton(action: onBack)

                Spacer()
            }

            VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
        }
    }

    func handleContinue() {
        guard let resolvedSelectedOption else { return }
        onContinue(resolvedSelectedOption)
    }

    var resolvedSelectedOption: VerificationOption? {
        if let selectedOptionId,
           let match = options.first(where: { $0.id == selectedOptionId }) {
            return match
        }
        return options.first
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
                .frame(maxWidth: 300)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(
                            isSelected ? Color.loopedContrast : Color.loopedTextSecondary.opacity(0.3),
                            lineWidth: 1.5
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    WaysToVerifyView(
        selectedOptionId: .constant("photo_id"),
        onBack: {},
        onContinue: { _ in },
        onSkip: {},
        onLearnMore: {}
    )
}
