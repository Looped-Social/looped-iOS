import SwiftUI

struct VerificationInfoOnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("verification-intro")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 150)
                    .padding(.top, 12)

                VStack(spacing: 10) {
                    Text("Posting is per community")
                        .font(.loopedCustom(.semibold, size: 24, relativeTo: .title2))
                        .foregroundColor(.loopedContrast)
                        .multilineTextAlignment(.center)

                    Text(.init("Every **post** belongs to a community. **Post, like, and comment** are available only where you're **verified**."))
                        .font(.loopedCustom(.regular, size: 14, relativeTo: .subheadline))
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                }

                PostingRulesCardView()

                Text("You can verify anytime from a community page.")
                    .font(.loopedCustom(.regular, size: 13, relativeTo: .footnote))
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(.init("Questions? Visit our [FAQ](https://mylooped.app/faq) or our [About](https://mylooped.app/about)."))
                    .font(.loopedCustom(.regular, size: 14, relativeTo: .body))
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)
                    .tint(.loopedSecondary)

                PrimaryButton(title: "Continue", action: onContinue)
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
}

private struct PostingRulesCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Access by verification status")
                .font(.loopedCustom(.medium, size: 13, relativeTo: .footnote))
                .foregroundColor(.loopedTextSecondary)
                .padding(.horizontal, 2)

            PostingRulesStateCardView(
                rowLabel: "Verified in this community",
                statuses: [.allowed, .allowed, .allowed, .allowed, .allowed]
            )

            PostingRulesStateCardView(
                rowLabel: "Not verified in this community",
                statuses: [.allowed, .locked, .locked, .locked, .allowed]
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.loopedMutedBackground.opacity(0.45))
        .cornerRadius(14)
        .accessibilityElement(children: .contain)
    }
}

private struct PostingRulesStateCardView: View {
    let rowLabel: String
    let statuses: [PostingPermissionStatus]

    private let actions = ["Browse", "Post", "Like", "Comment", "Repost"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(rowLabel)
                .font(.loopedCustom(.medium, size: 14, relativeTo: .headline))
                .foregroundColor(.loopedTextPrimary)

            VStack(spacing: 8) {
                ForEach(Array(zip(actions.indices, actions)), id: \.0) { index, action in
                    PostingRuleRowView(action: action, status: statuses[index])
                }
            }
        }
        .padding(12)
        .background(Color.loopedBackground.opacity(0.92))
        .cornerRadius(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PostingRuleRowView: View {
    let action: String
    let status: PostingPermissionStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.iconName)
                .font(.loopedSymbol(.semibold, size: 16))
                .foregroundColor(status.iconColor)

            Text(action)
                .font(.loopedCustom(.medium, size: 13, relativeTo: .body))
                .foregroundColor(status.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 8)

            Text(status.badgeText)
                .font(.loopedCustom(.regular, size: 12, relativeTo: .caption))
                .foregroundColor(status.badgeColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(status.backgroundColor)
        .cornerRadius(10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(action), \(status.voiceOverText)")
    }
}

private enum PostingPermissionStatus {
    case allowed
    case locked

    var iconName: String {
        switch self {
        case .allowed:
            return "checkmark.circle.fill"
        case .locked:
            return "lock.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .allowed:
            return .loopedSuccess
        case .locked:
            return .loopedTextSecondary
        }
    }

    var textColor: Color {
        switch self {
        case .allowed:
            return .loopedTextPrimary
        case .locked:
            return .loopedTextSecondary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .allowed:
            return .loopedBackground.opacity(0.95)
        case .locked:
            return .loopedMutedBackground.opacity(0.62)
        }
    }

    var badgeText: String {
        switch self {
        case .allowed:
            return "Available"
        case .locked:
            return "Locked"
        }
    }

    var badgeColor: Color {
        switch self {
        case .allowed:
            return .loopedTextSecondary
        case .locked:
            return .loopedTextSecondary
        }
    }

    var voiceOverText: String {
        switch self {
        case .allowed:
            return "allowed"
        case .locked:
            return "locked"
        }
    }
}

#Preview {
    NavigationStack {
        VerificationInfoOnboardingView(onContinue: {})
    }
}
