import SwiftUI

struct VerificationProgressView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.loopedSecondary : Color.loopedTextSecondary.opacity(0.2))
                    .frame(width: step == currentStep ? 22 : 10, height: 4)
            }
        }
        .accessibilityLabel("Step \(currentStep) of \(totalSteps)")
    }
}
