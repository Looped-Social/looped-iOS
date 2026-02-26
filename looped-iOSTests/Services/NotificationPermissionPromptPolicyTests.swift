import Foundation
import Testing
import UserNotifications
@testable import looped_iOS

@Suite
struct NotificationPermissionPromptPolicyTests {
    @Test
    func promptsImmediatelyWhenNotDeterminedAndNeverPrompted() {
        let shouldPrompt = NotificationPermissionPromptPolicy.shouldPrompt(
            authorizationStatus: .notDetermined,
            lastPromptedAt: 0
        )

        #expect(shouldPrompt == true)
    }

    @Test
    func notDeterminedUsesFourteenDayCooldown() {
        let now = Date()
        let justBeforeCooldown = now.addingTimeInterval(-NotificationPermissionPromptPolicy.notDeterminedCooldown + 60).timeIntervalSince1970
        let atCooldown = now.addingTimeInterval(-NotificationPermissionPromptPolicy.notDeterminedCooldown).timeIntervalSince1970

        #expect(
            NotificationPermissionPromptPolicy.shouldPrompt(
                authorizationStatus: .notDetermined,
                lastPromptedAt: justBeforeCooldown,
                now: now
            ) == false
        )
        #expect(
            NotificationPermissionPromptPolicy.shouldPrompt(
                authorizationStatus: .notDetermined,
                lastPromptedAt: atCooldown,
                now: now
            ) == true
        )
    }

    @Test
    func deniedUsesThirtyDayCooldown() {
        let now = Date()
        let justBeforeCooldown = now.addingTimeInterval(-NotificationPermissionPromptPolicy.deniedCooldown + 60).timeIntervalSince1970
        let atCooldown = now.addingTimeInterval(-NotificationPermissionPromptPolicy.deniedCooldown).timeIntervalSince1970

        #expect(
            NotificationPermissionPromptPolicy.shouldPrompt(
                authorizationStatus: .denied,
                lastPromptedAt: justBeforeCooldown,
                now: now
            ) == false
        )
        #expect(
            NotificationPermissionPromptPolicy.shouldPrompt(
                authorizationStatus: .denied,
                lastPromptedAt: atCooldown,
                now: now
            ) == true
        )
    }

    @Test
    func doesNotPromptWhenAlreadyAuthorized() {
        let statuses: [UNAuthorizationStatus] = [.authorized, .provisional, .ephemeral]
        for status in statuses {
            let shouldPrompt = NotificationPermissionPromptPolicy.shouldPrompt(
                authorizationStatus: status,
                lastPromptedAt: 0
            )
            #expect(shouldPrompt == false)
        }
    }
}
