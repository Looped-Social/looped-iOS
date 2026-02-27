import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct NotificationPreferencesViewModelTests {

    @Test
    func loadPreferences_success_setsPreferences() async {
        let service = MockNotificationService()
        let expected = TestFixtures.notificationPreferences(allEnabled: true)
        service.fetchPreferencesHandler = { expected }

        let viewModel = NotificationPreferencesViewModel(notificationService: service)
        await viewModel.loadPreferences()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.preferences?.channels.push.enabled == true)
        #expect(service.fetchPreferencesCallCount == 1)
    }

    @Test
    func loadPreferences_failure_setsError() async {
        let service = MockNotificationService()
        service.fetchPreferencesHandler = { throw TestError(message: "load failed") }

        let viewModel = NotificationPreferencesViewModel(notificationService: service)
        await viewModel.loadPreferences()

        #expect(viewModel.preferences == nil)
        #expect(viewModel.errorMessage == "load failed")
        #expect(viewModel.isLoading == false)
    }

    @Test
    func setChannelEnabled_success_appliesServerState() async {
        let service = MockNotificationService()
        let base = TestFixtures.notificationPreferences(allEnabled: true)
        let server = updating(base) { prefs in
            var push = prefs.channels.push
            push.enabled = false
            prefs.channels.push = push
        }

        let viewModel = NotificationPreferencesViewModel(notificationService: service)
        viewModel.preferences = base
        service.updatePreferencesHandler = { _ in server }

        await viewModel.setChannelEnabled(.push, isOn: false)

        #expect(viewModel.preferences?.channels.push.enabled == false)
        #expect(viewModel.errorMessage == nil)
        #expect(service.updateRequests.count == 1)
        #expect(service.updateRequests.first?.channels.push?.enabled == false)
    }

    @Test
    func setTypeEnabled_failure_rollsBackOptimisticChange() async {
        let service = MockNotificationService()
        let base = TestFixtures.notificationPreferences(allEnabled: true)

        let viewModel = NotificationPreferencesViewModel(notificationService: service)
        viewModel.preferences = base
        service.updatePreferencesHandler = { _ in throw TestError(message: "update failed") }

        await viewModel.setTypeEnabled(channel: .email, type: .mention, isOn: false)

        let mention = viewModel.preferences?.channels.email.types.value(for: .mention)
        #expect(mention == true)
        #expect(viewModel.errorMessage == "update failed")
    }

    @Test
    func setTypeEnabled_retryAfterFailure_succeeds() async {
        let service = MockNotificationService()
        let base = TestFixtures.notificationPreferences(allEnabled: true)
        var callCount = 0
        service.updatePreferencesHandler = { _ in
            defer { callCount += 1 }
            if callCount == 0 {
                throw TestError(message: "temporary")
            }
            return updating(base) { prefs in
                var push = prefs.channels.push
                push.types.set(false, for: .dmMessage)
                prefs.channels.push = push
            }
        }

        let viewModel = NotificationPreferencesViewModel(notificationService: service)
        viewModel.preferences = base

        await viewModel.setTypeEnabled(channel: .push, type: .dmMessage, isOn: false)
        #expect(viewModel.errorMessage == "temporary")

        await viewModel.setTypeEnabled(channel: .push, type: .dmMessage, isOn: false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.preferences?.channels.push.types.value(for: .dmMessage) == false)
    }

    @Test
    func setPrivacyMode_success_updatesServerAndLocal() async {
        let service = MockNotificationService()
        let base = TestFixtures.notificationPreferences(allEnabled: true)
        let server = updating(base) { prefs in
            prefs.privacyMode = .detailed
        }

        let viewModel = NotificationPreferencesViewModel(notificationService: service)
        viewModel.preferences = base
        service.updatePreferencesHandler = { update in
            #expect(update.privacyMode == .detailed)
            return server
        }

        await viewModel.setPrivacyMode(.detailed)

        #expect(viewModel.preferences?.privacyMode == .detailed)
        #expect(viewModel.errorMessage == nil)
    }
}

private func updating(
    _ preferences: NotificationPreferencesDTO,
    mutate: (inout NotificationPreferencesDTO) -> Void
) -> NotificationPreferencesDTO {
    var copy = preferences
    mutate(&copy)
    return copy
}
