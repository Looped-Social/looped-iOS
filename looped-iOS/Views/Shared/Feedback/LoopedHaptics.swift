import UIKit

enum LoopedHaptics {
    static func lightImpact() {
        Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    static func success() {
        Task { @MainActor in
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
}
