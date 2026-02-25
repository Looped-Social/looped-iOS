import SwiftUI

struct ProfileCompletionPromptView: View {
    let status: ProfileCompletionStatus?
    let onFinishNow: () -> Void
    let onNotNow: () async -> String?

    @State private var isSubmittingNotNow = false
    @State private var dismissalErrorMessage: String?

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.loopedCustom(size: 52))
                        .foregroundColor(.loopedPrimary)
                        .accessibilityHidden(true)

                    Text("Finish Your Profile")
                        .font(.loopedHeadingMedium)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Complete your profile so people can recognize you in your communities.")
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if !missingItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(missingItems, id: \.self) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.loopedSymbol(.semibold, size: 8))
                                    .foregroundColor(.loopedPrimary)
                                    .accessibilityHidden(true)

                                Text(item.title)
                                    .font(.loopedSubBodyRegular)
                                    .foregroundColor(.loopedTextPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
                }

                if let dismissalErrorMessage, !dismissalErrorMessage.isEmpty {
                    Text(dismissalErrorMessage)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedError)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(
                        title: "Finish Now",
                        isEnabled: !isSubmittingNotNow
                    ) {
                        onFinishNow()
                    }

                    StyledButton(
                        title: "Not Now",
                        style: MutedSecondaryButtonStyle(),
                        isEnabled: !isSubmittingNotNow,
                        isLoading: isSubmittingNotNow
                    ) {
                        dismissPrompt()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

private extension ProfileCompletionPromptView {
    var missingItems: [ProfileCompletionStatus.MissingItem] {
        status?.missingItems ?? []
    }

    func dismissPrompt() {
        guard !isSubmittingNotNow else { return }
        dismissalErrorMessage = nil
        isSubmittingNotNow = true

        Task {
            let maybeError = await onNotNow()
            await MainActor.run {
                dismissalErrorMessage = maybeError
                isSubmittingNotNow = false
            }
        }
    }
}

#Preview {
    ProfileCompletionPromptView(
        status: ProfileCompletionStatus(
            shouldPrompt: true,
            missingPhoto: true,
            missingBio: true,
            missingSpecialization: true,
            dismissedAt: nil,
            completedAt: nil
        ),
        onFinishNow: {},
        onNotNow: { nil }
    )
}
