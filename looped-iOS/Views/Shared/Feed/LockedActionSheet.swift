import SwiftUI

struct LockedActionSheet: View {
    let reason: LockReason
    let actionType: LockedFeedActionType
    let isPrimaryLoading: Bool
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let onHowItWorks: (() -> Void)?

    var body: some View {
        ZStack {
            Color.loopedBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.loopedMutedBackground)
                        .frame(width: 40, height: 40)
                    Image("lock-icon")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.loopedSecondary)
                }
                .padding(.top, 4)

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
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
                .disabled(isPrimaryLoading)
                .opacity(isPrimaryLoading ? 0.8 : 1)

                Button(reason.secondaryButtonTitle, action: onSecondary)
                    .buttonStyle(.plain)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextSecondary)

                if let onHowItWorks {
                    Button("How it works", action: onHowItWorks)
                        .buttonStyle(.plain)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedPrimary)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .top)
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
