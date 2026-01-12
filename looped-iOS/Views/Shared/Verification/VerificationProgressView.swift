import SwiftUI

struct VerificationProgressView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        let safeTotal = max(totalSteps, 1)
        let safeCurrent = min(max(currentStep, 0), safeTotal)
        let percent = Int((Double(safeCurrent) / Double(safeTotal)) * 100.0)
        let remaining = max(safeTotal - safeCurrent, 0)

        VStack(spacing: 4) {
            Text("\(safeCurrent)/\(safeTotal) • \(remaining) left • \(percent)%")
                .font(.loopedSmallText)
                .foregroundColor(.loopedTextSecondary)

            HStack(spacing: 6) {
                ForEach(1...safeTotal, id: \.self) { step in
                    Capsule()
                        .fill(step <= safeCurrent ? Color.loopedSecondary : Color.loopedTextSecondary.opacity(0.2))
                        .frame(width: step == safeCurrent ? 22 : 10, height: 4)
                }
            }
        }
        .accessibilityLabel("Step \(safeCurrent) of \(safeTotal), \(percent)% complete")
    }
}
