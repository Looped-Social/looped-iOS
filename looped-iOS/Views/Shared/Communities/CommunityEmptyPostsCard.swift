import SwiftUI

struct CommunityEmptyPostsCard: View {
    let illustrationName: String
    let title: String
    let message: String
    let showsPrimaryButton: Bool
    let primaryButtonTitle: String
    let isPrimaryButtonEnabled: Bool
    let isPrimaryButtonLoading: Bool
    let onCreatePost: () -> Void
    let onShareCommunity: () -> Void

    private struct BorderlessSecondaryButtonStyle: LoopedButtonStyle {
        let backgroundColor: Color = Color.loopedMutedBackground.opacity(0.65)
        let foregroundColor: Color = .loopedTextPrimary
        let cornerRadius: CGFloat = 12
        let height: CGFloat = 50
        let borderColor: Color? = nil
        let borderWidth: CGFloat = 0
    }

    init(
        illustrationName: String = "community-confirm",
        title: String = "Plant the first seed",
        message: String = "Ask a question, share a win, or post a tip. The first post makes it easy for others to join in.",
        showsPrimaryButton: Bool = true,
        primaryButtonTitle: String = "Create a post",
        isPrimaryButtonEnabled: Bool = true,
        isPrimaryButtonLoading: Bool = false,
        onCreatePost: @escaping () -> Void,
        onShareCommunity: @escaping () -> Void
    ) {
        self.illustrationName = illustrationName
        self.title = title
        self.message = message
        self.showsPrimaryButton = showsPrimaryButton
        self.primaryButtonTitle = primaryButtonTitle
        self.isPrimaryButtonEnabled = isPrimaryButtonEnabled
        self.isPrimaryButtonLoading = isPrimaryButtonLoading
        self.onCreatePost = onCreatePost
        self.onShareCommunity = onShareCommunity
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(illustrationName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 160)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)

            if showsPrimaryButton {
                HStack(spacing: 12) {
                    PrimaryButton(
                        title: primaryButtonTitle,
                        isEnabled: isPrimaryButtonEnabled,
                        isLoading: isPrimaryButtonLoading
                    ) {
                        onCreatePost()
                    }

                    StyledButton(title: "Share", style: BorderlessSecondaryButtonStyle()) {
                        onShareCommunity()
                    }
                    .accessibilityLabel("Share community")
                }
            } else {
                StyledButton(title: "Share", style: BorderlessSecondaryButtonStyle()) {
                    onShareCommunity()
                }
                .accessibilityLabel("Share community")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
        .background(Color.loopedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.loopedTextSecondary.opacity(0.08), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    CommunityEmptyPostsCard(
        onCreatePost: {},
        onShareCommunity: {}
    )
    .background(Color.loopedBackground.ignoresSafeArea())
}
