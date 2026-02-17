import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
struct NotificationDeviceRegistrarTests {

    @Test
    func registersTokenAfterAuthenticationAndAvoidsDuplicateRegistration() async {
        let defaults = makeRegistrarDefaults()
        let deviceService = MockDeviceService()
        let registrar = NotificationDeviceRegistrar(deviceService: deviceService, userDefaults: defaults)

        registrar.storeDeviceToken("token-1")
        #expect(deviceService.registerCalls.isEmpty)

        registrar.updateAuthState(isAuthenticated: true)
        await waitFor { deviceService.registerCalls.count == 1 }

        #expect(deviceService.registerCalls == ["token-1"])
        #expect(defaults.string(forKey: "apnsDeviceTokenRegistered") == "token-1")

        registrar.updateAuthState(isAuthenticated: true)
        try? await Task.sleep(nanoseconds: 80_000_000)
        #expect(deviceService.registerCalls.count == 1)
    }

    @Test
    func registersAgainWhenTokenChanges() async {
        let defaults = makeRegistrarDefaults()
        let deviceService = MockDeviceService()
        let registrar = NotificationDeviceRegistrar(deviceService: deviceService, userDefaults: defaults)

        registrar.updateAuthState(isAuthenticated: true)
        registrar.storeDeviceToken("token-1")
        await waitFor { deviceService.registerCalls.count == 1 }

        registrar.storeDeviceToken("token-2")
        await waitFor { deviceService.registerCalls.count == 2 }

        #expect(deviceService.registerCalls == ["token-1", "token-2"])
        #expect(defaults.string(forKey: "apnsDeviceTokenRegistered") == "token-2")
    }
}

private func makeRegistrarDefaults() -> UserDefaults {
    let suite = "looped.tests.registrar.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

private func waitFor(
    timeout: TimeInterval = 1.5,
    condition: @escaping () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}
