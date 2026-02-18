import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
struct OnboardingProgressStoreTests {

    @Test
    func saveAndLoadProgress_respectsActiveUserScope() {
        let suite = "looped.tests.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = OnboardingProgressStore(
            defaults: defaults,
            keychain: KeychainStore(),
            userIdProvider: { nil }
        )

        store.saveProgress(.profileSetup)
        #expect(store.loadProgress() == .profileSetup)

        store.saveProgress(.verificationInfo)
        #expect(store.loadProgress() == .verificationInfo)

        store.setActiveUserId("userA")
        store.saveProgress(.selectCompany)

        store.setActiveUserId("userB")
        store.saveProgress(.selectSchool)

        store.setActiveUserId("userA")
        #expect(store.loadProgress() == .selectCompany)

        store.setActiveUserId("userB")
        #expect(store.loadProgress() == .selectSchool)

        store.setActiveUserId(nil)
        #expect(store.loadProgress() == .verificationInfo)

        defaults.removePersistentDomain(forName: suite)
    }

    @Test
    func clearAllForUser_clearsOnlyTargetedScope() {
        let suite = "looped.tests.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = OnboardingProgressStore(
            defaults: defaults,
            keychain: KeychainStore(),
            userIdProvider: { nil }
        )

        store.setActiveUserId("userA")
        store.saveProgress(.selectCompany)
        store.saveVerificationMethod("email")

        store.setActiveUserId("userB")
        store.saveProgress(.verificationConfirmation)
        store.saveVerificationMethod("photo_id")

        store.clearAll(forUserId: "userA")

        store.setActiveUserId("userA")
        #expect(store.loadProgress() == nil)
        #expect(store.loadVerificationMethod() == nil)

        store.setActiveUserId("userB")
        #expect(store.loadProgress() == .verificationConfirmation)
        #expect(store.loadVerificationMethod() == "photo_id")

        defaults.removePersistentDomain(forName: suite)
    }

    @Test
    func migrateLegacyGlobalScope_copiesDefaultsDataToScopedKeys() {
        let suite = "looped.tests.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        defaults.set(OnboardingStep.selectSchool.rawValue, forKey: "looped.onboarding.progress")
        let draft = OnboardingOrganizationDraft(
            backendId: 44,
            name: "Legacy Org",
            kind: .school,
            imageURL: nil
        )
        defaults.set(try? JSONEncoder().encode(draft), forKey: "looped.onboarding.organizationDraft")
        defaults.set("email", forKey: "looped.onboarding.verificationMethod")

        let store = OnboardingProgressStore(
            defaults: defaults,
            keychain: KeychainStore(),
            userIdProvider: { nil }
        )

        store.migrateLegacyGlobalScopeIfNeeded(toUserId: "userLegacy")
        store.setActiveUserId("userLegacy")

        #expect(store.loadProgress() == .selectSchool)
        #expect(store.loadOrganizationDraft()?.backendId == 44)
        #expect(store.loadVerificationMethod() == "email")

        store.clearLegacyGlobalScope()
        #expect(defaults.string(forKey: "looped.onboarding.progress") == nil)
        #expect(defaults.data(forKey: "looped.onboarding.organizationDraft") == nil)
        #expect(defaults.string(forKey: "looped.onboarding.verificationMethod") == nil)

        defaults.removePersistentDomain(forName: suite)
    }
}
