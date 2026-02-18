import SwiftUI

struct VerificationInfoOnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("verification-intro")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 258, maxHeight: 162)
                    .padding(.top, 12)

                VStack(spacing: 10) {
                    Text("Posting is per community")
                        .font(.loopedCustom(.regular, size: 24, relativeTo: .title2))
                        .foregroundColor(.loopedContrast)
                        .multilineTextAlignment(.center)

                    Text("Every post belongs to a community. Post, like, and comment are available only where you're verified.")
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
    private let matrixRows: [PostingPermissionsMatrixRow] = [
        .init(action: "Browse", verified: .allowed, notVerified: .allowed),
        .init(action: "Post", verified: .allowed, notVerified: .restricted),
        .init(action: "Like", verified: .allowed, notVerified: .restricted),
        .init(action: "Comment", verified: .allowed, notVerified: .restricted),
        .init(action: "Repost", verified: .allowed, notVerified: .allowed)
    ]

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(minimum: 120), spacing: 0, alignment: .leading),
        GridItem(.flexible(minimum: 82), spacing: 0, alignment: .center),
        GridItem(.flexible(minimum: 112), spacing: 0, alignment: .center)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Access in a community")
                .font(.loopedCustom(.regular, size: 13, relativeTo: .footnote))
                .foregroundColor(.loopedTextSecondary)
                .padding(.horizontal, 2)

            LazyVGrid(columns: gridColumns, spacing: 0) {
                PostingRulesHeaderCell(title: "Action", isLeading: true)
                PostingRulesHeaderCell(title: "Verified", isLeading: false)
                PostingRulesHeaderCell(title: "Not verified", isLeading: false)

                ForEach(matrixRows) { row in
                    PostingRulesActionCell(title: row.action)
                    PostingRulesStatusCell(status: row.verified)
                    PostingRulesStatusCell(status: row.notVerified)
                }
            }
            .background(Color.loopedBackground.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.loopedMutedBackground.opacity(0.45))
        .cornerRadius(14)
        .accessibilityElement(children: .contain)
    }
}

private struct PostingPermissionsMatrixRow: Identifiable {
    let action: String
    let verified: PostingPermissionStatus
    let notVerified: PostingPermissionStatus

    var id: String { action }
}

private struct PostingRulesHeaderCell: View {
    let title: String
    let isLeading: Bool

    var body: some View {
        Text(title)
            .font(.loopedCustom(.regular, size: 12, relativeTo: .caption))
            .foregroundColor(.loopedTextSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .padding(.horizontal, isLeading ? 10 : 6)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: isLeading ? .leading : .center)
            .background(Color.loopedMutedBackground.opacity(0.35))
            .overlay(
                Rectangle()
                    .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 0.5)
            )
    }
}

private struct PostingRulesActionCell: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.loopedCustom(.regular, size: 13, relativeTo: .body))
            .foregroundColor(.loopedTextPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Color.loopedBackground.opacity(0.94))
            .overlay(
                Rectangle()
                    .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 0.5)
            )
    }
}

private struct PostingRulesStatusCell: View {
    let status: PostingPermissionStatus

    var body: some View {
        status.icon
            .frame(width: 20, height: 20)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(status.backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 0.5)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(status.voiceOverText)
    }
}

private enum PostingPermissionStatus {
    case allowed
    case restricted

    @ViewBuilder
    var icon: some View {
        switch self {
        case .allowed:
            Image(systemName: "checkmark")
                .font(.loopedSymbol(.semibold, size: 18))
                .foregroundColor(.loopedSuccess)
        case .restricted:
            Image("error-toast")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundColor(.loopedError)
        }
    }

    var backgroundColor: Color {
        switch self {
        case .allowed:
            return .loopedSuccess.opacity(0.1)
        case .restricted:
            return .loopedError.opacity(0.1)
        }
    }

    var voiceOverText: String {
        switch self {
        case .allowed:
            return "Allowed"
        case .restricted:
            return "Not allowed"
        }
    }
}

#Preview {
    NavigationStack {
        VerificationInfoOnboardingView(onContinue: {})
    }
}
