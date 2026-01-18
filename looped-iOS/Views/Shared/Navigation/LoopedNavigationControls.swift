import SwiftUI
import UIKit

struct LoopedBackButton: View {
    let action: () -> Void
    var usesHaptics: Bool = false
    var foregroundColor: Color = .loopedTextSecondary
    var iconSize: CGFloat = 24
    var iconWeight: LoopedFontWeight = .medium
    var hitWidth: CGFloat = 36
    var hitHeight: CGFloat = 44

    var body: some View {
        Button(action: trigger) {
            Image(systemName: "chevron.left")
                .font(.loopedCustom(iconWeight, size: iconSize))
                .foregroundColor(foregroundColor)
                .frame(width: hitWidth, height: hitHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private func trigger() {
        if usesHaptics {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
        action()
    }
}

struct LoopedCloseButton: View {
    let action: () -> Void
    var foregroundColor: Color = .loopedTextSecondary
    var iconSize: CGFloat = 16
    var iconWeight: LoopedFontWeight = .semibold
    var hitArea: CGFloat = 44

    var showsBackground: Bool = true
    var backgroundColor: Color = .loopedMutedBackground
    var backgroundOpacity: Double = 1

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.loopedCustom(iconWeight, size: iconSize))
                .foregroundColor(foregroundColor)
                .frame(width: hitArea, height: hitArea)
                .contentShape(Rectangle())
                .background(alignment: .center) {
                    if showsBackground {
                        Circle()
                            .fill(backgroundColor.opacity(backgroundOpacity))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

struct LoopedCancelTextButton: View {
    let action: () -> Void
    var title: String = "Cancel"
    var foregroundColor: Color = .loopedSecondary
    var font: Font = .loopedSubBodyMedium

    var body: some View {
        Button(title, action: action)
            .font(font)
            .foregroundColor(foregroundColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .buttonStyle(.plain)
    }
}
