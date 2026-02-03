import SwiftUI

enum PillButtonLabelSize {
    case regular
    case profile
    case compact

    var font: Font {
        switch self {
        case .regular:
            return .loopedBodyStrong
        case .profile:
            return .loopedSubBodyMedium
        case .compact:
            return .loopedSubBodyMedium
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .regular:
            return 32
        case .profile:
            return 22
        case .compact:
            return 16
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .regular:
            return 12
        case .profile:
            return 10
        case .compact:
            return 8
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .regular:
            return 44
        case .profile:
            return 40
        case .compact:
            return 36
        }
    }
}

enum PillButtonLabelVariant {
    case primary
    case muted
    case secondary

    func textColor(isEnabled: Bool) -> Color {
        guard isEnabled else { return .loopedTextSecondary.opacity(0.75) }
        switch self {
        case .primary, .secondary:
            return .loopedWhite
        case .muted:
            return .loopedTextPrimary
        }
    }

    func backgroundColor(isEnabled: Bool) -> Color {
        guard isEnabled else { return .loopedMutedBackground.opacity(0.35) }
        switch self {
        case .primary:
            return .loopedPrimary
        case .secondary:
            return .loopedSecondary
        case .muted:
            return .loopedMutedBackground
        }
    }
}

struct PillButtonLabel: View {
    let title: String
    let variant: PillButtonLabelVariant
    var size: PillButtonLabelSize = .regular
    var fillWidth: Bool = false
    var isEnabled: Bool = true
    var showsLoadingIndicator: Bool = false

    var body: some View {
        let textColor = variant.textColor(isEnabled: isEnabled)
        let backgroundColor = variant.backgroundColor(isEnabled: isEnabled)

        return HStack(spacing: 8) {
            Text(title)
                .font(size.font)
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)

            if showsLoadingIndicator {
                ProgressView()
                    .tint(textColor)
                    .scaleEffect(0.85)
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(minHeight: size.minHeight)
        .frame(maxWidth: fillWidth ? .infinity : nil)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
}

struct FollowPillButtonLabel: View {
    let title: String
    let isFollowing: Bool
    var size: PillButtonLabelSize = .regular
    var fillWidth: Bool = false
    var isEnabled: Bool = true
    var showsLoadingIndicator: Bool = false

    var body: some View {
        PillButtonLabel(
            title: title,
            variant: isFollowing ? .muted : .primary,
            size: size,
            fillWidth: fillWidth,
            isEnabled: isEnabled,
            showsLoadingIndicator: showsLoadingIndicator
        )
    }
}
