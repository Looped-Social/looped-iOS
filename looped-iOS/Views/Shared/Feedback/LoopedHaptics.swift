import UIKit

enum LoopedHaptics {
    @MainActor
    private static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    static func lightImpact() {
        Task { @MainActor in
            impact(style: .soft, intensity: 0.45)
        }
    }

    static func success() {
        Task { @MainActor in
            impact(style: .soft, intensity: 0.65)
        }
    }

    static func verificationSuccess() {
        Task { @MainActor in
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
}
