import SwiftUI

enum CoachMarkTarget: Hashable {
    case profileEditButton
    case profileAnonymousButton
    case profileSettingsButton
    case profileStats
    case feedPostButton
    case feedFilterPills
}

struct CoachMarkTargetKey: PreferenceKey {
    static var defaultValue: [CoachMarkTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [CoachMarkTarget: Anchor<CGRect>], nextValue: () -> [CoachMarkTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func coachMarkTarget(_ target: CoachMarkTarget) -> some View {
        anchorPreference(key: CoachMarkTargetKey.self, value: .bounds) { [target: $0] }
    }
}

struct CoachMarkOverlay: View {
    let target: CoachMarkTarget
    let targets: [CoachMarkTarget: Anchor<CGRect>]
    let message: String
    let primaryTitle: String
    let secondaryTitle: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let rect = targets[target].map { proxy[$0] }
            let highlightRect = rect?.insetBy(dx: -8, dy: -8)

            ZStack {
                Color.black.opacity(0.55)

                if let highlightRect {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .frame(width: highlightRect.width, height: highlightRect.height)
                        .position(x: highlightRect.midX, y: highlightRect.midY)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
            .ignoresSafeArea()
            .overlay(
                Group {
                    if let highlightRect {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.loopedPrimary, lineWidth: 2)
                            .frame(width: highlightRect.width, height: highlightRect.height)
                            .position(x: highlightRect.midX, y: highlightRect.midY)
                    }
                }
            )
            .overlay(
                CoachMarkCard(
                    message: message,
                    primaryTitle: primaryTitle,
                    secondaryTitle: secondaryTitle,
                    onPrimary: onPrimary,
                    onSecondary: onSecondary
                )
                .frame(width: min(320, proxy.size.width - 32))
                .padding(.horizontal, 16)
                .padding(.bottom, 80),
                alignment: .bottom
            )
        }
    }
}

private struct CoachMarkCard: View {
    let message: String
    let primaryTitle: String
    let secondaryTitle: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)

            HStack(spacing: 12) {
                if let secondaryTitle, let onSecondary {
                    Button(secondaryTitle, action: onSecondary)
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Button(primaryTitle, action: onPrimary)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.loopedPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.loopedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.loopedTextSecondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}
