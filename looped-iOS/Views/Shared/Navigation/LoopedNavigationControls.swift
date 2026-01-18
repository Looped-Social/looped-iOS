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

struct LoopedOverlayBackButton: View {
    let action: () -> Void
    var usesHaptics: Bool = true
    var foregroundColor: Color = .loopedTextSecondary
    var size: CGFloat = 36

    var body: some View {
        LoopedOverlayIconButton(
            systemName: "chevron.backward",
            action: action,
            usesHaptics: usesHaptics,
            foregroundColor: foregroundColor,
            size: size,
            accessibilityLabel: "Back"
        )
    }
}

struct LoopedOverlayIconButton: View {
    let systemName: String
    let action: () -> Void
    var usesHaptics: Bool = true
    var foregroundColor: Color = .loopedTextSecondary
    var size: CGFloat = 36
    var accessibilityLabel: String

    var body: some View {
        Button(action: trigger) {
            Image(systemName: systemName)
                .font(.loopedCustom(.semibold, size: 18))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(Color.loopedTextSecondary.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.loopedTextSecondary.opacity(0.10), radius: 10, x: 0, y: 4)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
