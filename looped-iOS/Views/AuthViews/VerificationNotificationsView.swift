import SwiftUI

@available(*, deprecated, message: "Replaced by NotificationPermissionPromptView + post-onboarding permission prompt in ContentView.")
struct VerificationNotificationsView: View {
    let loopName: String
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onEnableNotifications: (_ wantsRecommendations: Bool) -> Void
    let onSkip: () -> Void
    let showsHeader: Bool

    @State private var wantsRecommendations: Bool

    init(
        loopName: String = "Looped",
        currentStep: Int = 4,
        totalSteps: Int = 4,
        wantsRecommendations: Bool = true,
        onBack: @escaping () -> Void,
        onEnableNotifications: @escaping (_ wantsRecommendations: Bool) -> Void,
        onSkip: @escaping () -> Void,
        showsHeader: Bool = true
    ) {
        self.loopName = loopName
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onEnableNotifications = onEnableNotifications
        self.onSkip = onSkip
        self.showsHeader = showsHeader
        _wantsRecommendations = State(initialValue: wantsRecommendations)
    }

    var body: some View {
        NotificationPermissionPromptView {
            onSkip()
        }
    }
}

#Preview {
    VerificationNotificationsView(
        loopName: "Looped",
        onBack: { },
        onEnableNotifications: { _ in },
        onSkip: { }
    )
}
