import SwiftUI

struct VerificationInfoScreen: View {
    enum CloseButtonStyle {
        case none
        case xmark
    }

    let closeButtonStyle: CloseButtonStyle
    @Environment(\.dismiss) private var dismiss

    init(closeButtonStyle: CloseButtonStyle = .none) {
        self.closeButtonStyle = closeButtonStyle
    }

    var body: some View {
        VerificationInfoOnboardingView(showsContinue: false, onContinue: { dismiss() })
            .toolbar {
                if closeButtonStyle == .xmark {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.loopedSymbol(.semibold, size: 22))
                                .foregroundColor(.loopedTextSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                }
            }
    }
}

#Preview("Verification Info (Modal)") {
    NavigationStack {
        VerificationInfoScreen(closeButtonStyle: .xmark)
    }
}
