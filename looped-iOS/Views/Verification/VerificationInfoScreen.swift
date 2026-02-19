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
                        LoopedCloseButton(
                            action: { dismiss() },
                            foregroundColor: .loopedTextSecondary,
                            iconSize: 16,
                            iconWeight: .semibold,
                            hitArea: 36,
                            showsBackground: false
                        )
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
