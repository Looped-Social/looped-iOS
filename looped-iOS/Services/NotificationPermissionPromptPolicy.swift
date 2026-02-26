import Foundation
import UserNotifications

enum NotificationPermissionPromptPolicy {
    private static let dayInSeconds: TimeInterval = 24 * 60 * 60
    static let notDeterminedCooldown: TimeInterval = 14 * dayInSeconds
    static let deniedCooldown: TimeInterval = 30 * dayInSeconds

    static func shouldPrompt(
        authorizationStatus: UNAuthorizationStatus,
        lastPromptedAt: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return false
        case .notDetermined, .denied:
            guard lastPromptedAt > 0 else { return true }
            let elapsed = max(0, now.timeIntervalSince1970 - lastPromptedAt)
            return elapsed >= cooldownInterval(for: authorizationStatus)
        @unknown default:
            return false
        }
    }

    static func cooldownInterval(for authorizationStatus: UNAuthorizationStatus) -> TimeInterval {
        switch authorizationStatus {
        case .notDetermined:
            return notDeterminedCooldown
        case .denied:
            return deniedCooldown
        default:
            return .infinity
        }
    }
}
