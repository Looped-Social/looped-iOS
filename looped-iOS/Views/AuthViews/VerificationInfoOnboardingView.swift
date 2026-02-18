import SwiftUI

struct VerificationInfoOnboardingView: View {
    let onContinue: () -> Void

    @State private var hasAcknowledged = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image("verification-info")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 220)
                    .padding(.top, 12)

                VStack(spacing: 10) {
                    Text("How posting access works")
                        .font(.loopedHeadingMedium)
                        .foregroundColor(.loopedContrast)
                        .multilineTextAlignment(.center)

                    Text("You can view everything now. To post, like, or comment, verify and join a community.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    infoBullet("Posts are inside communities.")
                    infoBullet("No verification = view only.")
                    infoBullet("Up to 2 specializations.")
                    infoBullet("Work verification unlocks fields.")
                    infoBullet("College verification unlocks majors.")
                    infoBullet("You can verify anytime from a community page.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.loopedMutedBackground.opacity(0.35))
                .cornerRadius(12)

                Button(action: { hasAcknowledged.toggle() }) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: hasAcknowledged ? "checkmark.square.fill" : "square")
                            .font(.loopedSymbol(.semibold, size: 20))
                            .foregroundColor(hasAcknowledged ? .loopedPrimary : .loopedTextSecondary)

                        Text("I understand and I'm ready to continue.")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.loopedMutedBackground.opacity(0.5))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("auth.verificationInfo.acknowledgeButton")
                .accessibilityLabel("Acknowledge verification rules")
                .accessibilityValue(hasAcknowledged ? "Selected" : "Not selected")

                Text(.init("Questions? Visit our [FAQ](https://mylooped.app/faq) or our [About](https://mylooped.app/about)."))
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)
                    .tint(.loopedSecondary)

                PrimaryButton(title: "Continue", isEnabled: hasAcknowledged, action: onContinue)
                    .accessibilityIdentifier("auth.verificationInfo.continueButton")
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func infoBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.loopedTextSecondary)
                .frame(width: 5, height: 5)
                .padding(.top, 7)

            Text(text)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        VerificationInfoOnboardingView(onContinue: {})
    }
}
