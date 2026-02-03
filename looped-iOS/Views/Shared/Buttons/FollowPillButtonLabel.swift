import SwiftUI

enum FollowPillButtonLabelSize {
    case regular
    case compact

    var font: Font {
        switch self {
        case .regular:
            return .loopedBodyStrong
        case .compact:
            return .loopedSubBodyMedium
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .regular:
            return 32
        case .compact:
            return 16
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .regular:
            return 12
        case .compact:
            return 8
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .regular:
            return 44
        case .compact:
            return 36
        }
    }
}

struct FollowPillButtonLabel: View {
    let title: String
    let isFollowing: Bool
    var size: FollowPillButtonLabelSize = .regular
    var isEnabled: Bool = true
    var showsLoadingIndicator: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(size.font)
                .foregroundColor(textColor)

            if showsLoadingIndicator {
                ProgressView()
                    .tint(textColor)
                    .scaleEffect(0.85)
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(minHeight: size.minHeight)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    private var textColor: Color {
        guard isEnabled else { return .loopedTextSecondary.opacity(0.75) }
        return isFollowing ? .loopedTextPrimary : .loopedWhite
    }

    private var backgroundColor: Color {
        guard isEnabled else { return .loopedMutedBackground.opacity(0.35) }
        return isFollowing ? Color.loopedMutedBackground : Color.loopedPrimary
    }
}

