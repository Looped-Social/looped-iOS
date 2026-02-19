import SwiftUI

struct LockedActionSheet: View {
    let reason: LockReason
    let actionType: LockedFeedActionType
    let isPrimaryLoading: Bool
    let onPrimary: () -> Void
    let onHowItWorks: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Text(reason.title(for: actionType))
                .font(.loopedHeadlineScaled)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.center)

            Text(reason.body(for: actionType))
                .font(.loopedSubheadlineScaled)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

            Button(action: onPrimary) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.loopedPrimary)

                    if isPrimaryLoading {
                        ProgressView()
                            .tint(.loopedWhite)
                    } else {
                        Text(reason.primaryButtonTitle)
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedWhite)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: 44, maxHeight: 54)
            }
            .buttonStyle(.plain)
            .disabled(isPrimaryLoading)
            .opacity(isPrimaryLoading ? 0.8 : 1)

            if let onHowItWorks {
                Button(action: onHowItWorks) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.loopedSymbol(.medium, size: 14))
                        Text(helpLinkTitle)
                            .font(.loopedSmallTextMedium)
                    }
                    .foregroundColor(.loopedTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var helpLinkTitle: String {
        switch actionType {
        case .like:
            return "Why can't I like this post?"
        case .comment:
            return "Why can't I comment?"
        case .post:
            return "Why can't I post here?"
        }
    }
}

struct LockedActionCompactToast: View {
    let reason: LockReason
    let actionType: LockedFeedActionType
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image("lock-icon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundColor(.loopedSecondary)

            Text(reason.compactToastMessage(for: actionType))
                .font(.loopedSmallText)
                .foregroundColor(.loopedTextPrimary)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button(action: onPrimary) {
                Text(reason.compactPrimaryButtonTitle)
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedWhite)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.loopedPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.loopedMutedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.loopedTextSecondary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.loopedBlack.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

struct LockedActionSheetRequest: Identifiable {
    let id = UUID()
    let reason: LockReason
    let actionType: LockedFeedActionType
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let onHowItWorks: (() -> Void)?
}
