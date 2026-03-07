import Testing
import UserNotifications
@testable import looped_iOS

@Suite
struct NotificationSettingsViewStateTests {
    @Test
    func pushSubtitleShowsSettingsMessageWhenDenied() {
        let subtitle = NotificationSettingsView.pushNotificationsSubtitle(for: .denied)

        #expect(subtitle == "Disabled in iOS Settings")
        #expect(NotificationSettingsView.shouldShowOpenSettingsRow(for: .denied) == true)
    }

    @Test
    func pushSubtitleUsesDefaultMessageWhenNotDenied() {
        let statuses: [UNAuthorizationStatus] = [.notDetermined, .authorized, .provisional, .ephemeral]

        for status in statuses {
            let subtitle = NotificationSettingsView.pushNotificationsSubtitle(for: status)
            #expect(subtitle == "Receive notifications on this device")
            #expect(NotificationSettingsView.shouldShowOpenSettingsRow(for: status) == false)
        }
    }
}
