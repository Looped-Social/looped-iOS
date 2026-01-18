import SwiftUI

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
        currentStep: Int = 5,
        totalSteps: Int = 5,
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
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                if showsHeader {
                    header
                        .padding(.top, 8)
                }

                Spacer()
                    .frame(height: geometry.size.height * 0.06)

                Text("Turn on\nNotifications?")
                    .font(.loopedHeadingMedium32)
                    .foregroundColor(.loopedContrast)

                Image(systemName: "bell")
                    .font(.loopedCustom(.regular, size: 48))
                    .foregroundColor(.loopedContrast)
                    .padding(.top, 18)

                Text("Don't miss out on community\nevents and posts in \(loopName)")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.top, 18)

                HStack(alignment: .center, spacing: 12) {
                    Text("Get Personalized Recommendations\nand more for \(loopName)")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)

                    Spacer()

                    Toggle("", isOn: $wantsRecommendations)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Color.loopedSecondary))
                }
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { onEnableNotifications(wantsRecommendations) }) {
                        Text("Yes Notify me")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedWhite)
                            .frame(width: 200, height: 44)
                            .background(Color.loopedPrimary)
                            .clipShape(Capsule())
                    }

                    Button(action: onSkip) {
                        Text("No Skip")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                            .frame(width: 200, height: 44)
                            .background(Color.loopedMutedBackground)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 30)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
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

private extension VerificationNotificationsView {
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
    VerificationNotificationsView(
        loopName: "Looped",
        onBack: { },
        onEnableNotifications: { _ in },
        onSkip: {}
    )
}
