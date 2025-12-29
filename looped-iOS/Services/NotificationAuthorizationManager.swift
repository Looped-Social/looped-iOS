import Foundation
import UIKit
import UserNotifications

final class NotificationAuthorizationManager {
    static let shared = NotificationAuthorizationManager()

    private init() {}

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            await registerForRemoteNotifications()
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    await registerForRemoteNotifications()
                }
                return granted
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    @MainActor
    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
