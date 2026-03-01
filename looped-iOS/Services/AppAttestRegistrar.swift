import Foundation

final class AppAttestRegistrar {
    static let shared = AppAttestRegistrar()

    private let appAttestService: any AppAttestServiceProtocol
    private let anonService: AnonService
    private let userDefaults: UserDefaults

    private let anonymousModeKey = "anonymousMode"
    private let lastBackgroundAttemptAtKey = "looped.appAttest.lastBackgroundAttemptAt"
    private let backgroundRetryInterval: TimeInterval = 6 * 60 * 60

    private var isAuthenticated = false
    private var isRegistering = false

    init(
        appAttestService: any AppAttestServiceProtocol = AppAttestService(),
        anonService: AnonService = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.appAttestService = appAttestService
        self.anonService = anonService
        self.userDefaults = userDefaults
    }

    func updateAuthState(isAuthenticated: Bool) {
        self.isAuthenticated = isAuthenticated
        guard isAuthenticated else { return }
        registerIfEligible()
    }

    func appDidBecomeActive() {
        registerIfEligible()
    }

    private func registerIfEligible() {
        guard isAuthenticated else { return }
        guard !isRegistering else { return }

        isRegistering = true
        Task {
            defer { isRegistering = false }
            guard await shouldAttemptBackgroundRegistration() else { return }
            userDefaults.set(Date(), forKey: lastBackgroundAttemptAtKey)
            _ = await appAttestService.prepareForAnonymousEnrollment(forceRefresh: false)
        }
    }

    private func shouldAttemptBackgroundRegistration() async -> Bool {
        if await appAttestService.currentKeyId() != nil {
            return false
        }
        let hasAnonModeEnabled = userDefaults.bool(forKey: anonymousModeKey)
        let hasAnonIdentity = await anonService.currentIdentity() != nil
        guard hasAnonModeEnabled || hasAnonIdentity else {
            return false
        }

        if let lastAttemptAt = userDefaults.object(forKey: lastBackgroundAttemptAtKey) as? Date,
           Date().timeIntervalSince(lastAttemptAt) < backgroundRetryInterval {
            return false
        }

        return true
    }
}
