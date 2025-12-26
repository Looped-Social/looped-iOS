import Foundation

final class NotificationDeviceRegistrar {
    static let shared = NotificationDeviceRegistrar()

    private let deviceService: DeviceServiceProtocol
    private let tokenKey = "apnsDeviceToken"
    private let registeredTokenKey = "apnsDeviceTokenRegistered"
    private let userDefaults: UserDefaults

    private var isAuthenticated = false
    private var isRegistering = false

    init(
        deviceService: DeviceServiceProtocol = DeviceService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.deviceService = deviceService
        self.userDefaults = userDefaults
    }

    func updateAuthState(isAuthenticated: Bool) {
        self.isAuthenticated = isAuthenticated
        registerIfPossible()
    }

    func storeDeviceToken(_ token: String) {
        userDefaults.set(token, forKey: tokenKey)
        registerIfPossible()
    }

    private func registerIfPossible() {
        guard isAuthenticated else { return }
        guard !isRegistering else { return }
        guard let token = userDefaults.string(forKey: tokenKey), !token.isEmpty else { return }

        let lastRegistered = userDefaults.string(forKey: registeredTokenKey)
        guard token != lastRegistered else { return }

        isRegistering = true
        Task {
            defer { isRegistering = false }
            do {
                try await deviceService.registerDevice(apnsToken: token)
                userDefaults.set(token, forKey: registeredTokenKey)
            } catch {
                // Retry on next auth/token update.
            }
        }
    }
}
