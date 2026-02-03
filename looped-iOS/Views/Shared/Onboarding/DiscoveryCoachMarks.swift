import SwiftUI

enum CoachMarkTarget: Hashable {
    case profileEditButton
    case profileAnonymousButton
    case profileSettingsButton
    case profileStats
    case feedPostButton
    case feedFilterPills
    case mainTabSearch
}

private enum CoachMarkHighlightShape {
    case roundedRect(cornerRadius: CGFloat)
    case circle
}

private extension CoachMarkTarget {
    var highlightPadding: CGFloat {
        switch self {
        case .feedPostButton:
            return 14
        case .mainTabSearch:
            return 12
        case .profileSettingsButton:
            return 10
        case .feedFilterPills:
            return 10
        case .profileStats:
            return 10
        case .profileEditButton, .profileAnonymousButton:
            return 10
        }
    }

    var highlightShape: CoachMarkHighlightShape {
        switch self {
        case .feedPostButton, .profileSettingsButton, .mainTabSearch:
            return .circle
        case .feedFilterPills:
            return .roundedRect(cornerRadius: 18)
        case .profileStats:
            return .roundedRect(cornerRadius: 18)
        case .profileEditButton, .profileAnonymousButton:
            return .roundedRect(cornerRadius: 14)
        }
    }
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

    @State private var cardSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let rawRect = targets[target].map { proxy[$0] }
            let highlightFrame = rawRect.map { rect -> CGRect in
                let padded = rect.insetBy(dx: -target.highlightPadding, dy: -target.highlightPadding)
                switch target.highlightShape {
                case .roundedRect:
                    return padded
                case .circle:
                    let side = max(padded.width, padded.height)
                    return CGRect(x: padded.midX - (side / 2), y: padded.midY - (side / 2), width: side, height: side)
                }
            }

            ZStack {
                coachMarkBackdrop(highlightFrame: highlightFrame)
                    .allowsHitTesting(false)

                CoachMarkHitBlocker(highlightFrame: highlightFrame, containerSize: proxy.size)

                coachMarkCard(highlightFrame: highlightFrame, containerSize: proxy.size)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func coachMarkBackdrop(highlightFrame: CGRect?) -> some View {
        ZStack {
            Color.loopedBlack.opacity(0.55)

            if let highlightFrame {
                highlightCutout(frame: highlightFrame)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private func highlightCutout(frame: CGRect) -> some View {
        switch target.highlightShape {
        case .roundedRect(let cornerRadius):
            RoundedRectangle(cornerRadius: min(cornerRadius, min(frame.width, frame.height) / 2), style: .continuous)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        case .circle:
            Circle()
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    private func coachMarkCard(highlightFrame: CGRect?, containerSize: CGSize) -> some View {
        let cardWidth = min(320, containerSize.width - 32)

        return CoachMarkCard(
            message: message,
            primaryTitle: primaryTitle,
            secondaryTitle: secondaryTitle,
            onPrimary: onPrimary,
            onSecondary: onSecondary
        )
        .frame(width: cardWidth)
        .background(
            GeometryReader { cardProxy in
                Color.loopedClear.preference(key: CoachMarkCardSizeKey.self, value: cardProxy.size)
            }
        )
        .onPreferenceChange(CoachMarkCardSizeKey.self) { newSize in
            if newSize != .zero, newSize != cardSize {
                cardSize = newSize
            }
        }
        .position(cardPosition(highlightFrame: highlightFrame, cardWidth: cardWidth, containerSize: containerSize))
    }

    private func cardPosition(highlightFrame: CGRect?, cardWidth: CGFloat, containerSize: CGSize) -> CGPoint {
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 16

        let safeCardHalfWidth = cardWidth / 2
        let minX = horizontalPadding + safeCardHalfWidth
        let maxX = max(minX, containerSize.width - horizontalPadding - safeCardHalfWidth)

        let minY = verticalPadding + (cardSize.height / 2)
        let maxY = max(minY, containerSize.height - verticalPadding - (cardSize.height / 2))

        guard let highlightFrame, cardSize != .zero else {
            return CGPoint(
                x: containerSize.width / 2,
                y: maxY - 80
            )
        }

        let preferredX = min(max(highlightFrame.midX, minX), maxX)

        let spacing: CGFloat = 14
        let placeBelowFits = highlightFrame.maxY + spacing + cardSize.height <= containerSize.height - verticalPadding
        let preferredY = placeBelowFits
        ? (highlightFrame.maxY + spacing + (cardSize.height / 2))
        : (highlightFrame.minY - spacing - (cardSize.height / 2))

        let clampedY = min(max(preferredY, minY), maxY)
        return CGPoint(x: preferredX, y: clampedY)
    }
}

private struct CoachMarkCardSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct CoachMarkHitBlocker: View {
    let highlightFrame: CGRect?
    let containerSize: CGSize

    var body: some View {
        if let highlightFrame {
            VStack(spacing: 0) {
                blocker
                    .frame(height: max(highlightFrame.minY, 0))

                HStack(spacing: 0) {
                    blocker
                        .frame(width: max(highlightFrame.minX, 0))

                    Color.loopedClear
                        .frame(width: max(highlightFrame.width, 0), height: max(highlightFrame.height, 0))
                        .allowsHitTesting(false)

                    blocker
                        .frame(width: max(containerSize.width - highlightFrame.maxX, 0))
                }
                .frame(height: max(highlightFrame.height, 0))

                blocker
                    .frame(height: max(containerSize.height - highlightFrame.maxY, 0))
            }
        } else {
            blocker
        }
    }

    private var blocker: some View {
        Color.loopedBlack.opacity(0.001)
            .contentShape(Rectangle())
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
                    .foregroundColor(.loopedWhite)
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
        .shadow(color: Color.loopedBlack.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Presentation
enum CoachMarkOverlaySource {
    case profile
}

final class CoachMarkPresenter: ObservableObject {
    struct Overlay {
        let source: CoachMarkOverlaySource
        let target: CoachMarkTarget
        let message: String
        let primaryTitle: String
        let secondaryTitle: String?
        let onPrimary: () -> Void
        let onSecondary: (() -> Void)?
    }

    @Published var overlay: Overlay?

    func show(_ overlay: Overlay) {
        self.overlay = overlay
    }

    func dismissIfSource(_ source: CoachMarkOverlaySource) {
        guard overlay?.source == source else { return }
        overlay = nil
    }
}
