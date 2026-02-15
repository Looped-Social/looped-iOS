import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum OnboardingStep: String {
    case profileSetup
    case selectCompany
    case selectSchool
    case departmentSelection
    case degreeSelection
    case communitySelectionStudent
    case communitySelectionCompany
    case verificationIntroStudent
    case verificationIntroCompany
    case waysToVerifyCompany
    case waysToVerifyStudent
    case photoIdVerificationStudent
    case photoIdVerificationCompany
    case emailVerificationStudent
    case emailVerificationCompany
    case verificationConfirmation
    case verificationNotifications
}

struct OnboardingProfileDraft: Codable {
    let username: String
    let firstName: String
    let lastName: String
    let dateOfBirth: Date?
}

struct OnboardingOrganizationDraft: Codable {
    let backendId: Int?
    let name: String
    let kind: OrganizationKind
    let imageURL: String?
}

final class OnboardingProgressStore {
    private let progressKey = "looped.onboarding.progress"
    private let profileDraftKey = "looped.onboarding.profileDraft"
    private let organizationDraftKey = "looped.onboarding.organizationDraft"
    private let verificationMethodKey = "looped.onboarding.verificationMethod"
    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let userIdProvider: () -> String?
    private var activeUserIdOverride: String?

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore(),
        userIdProvider: @escaping () -> String? = OnboardingProgressStore.defaultUserIdProvider
    ) {
        self.defaults = defaults
        self.keychain = keychain
        self.userIdProvider = userIdProvider
    }

    var hasProgress: Bool {
        loadProgress() != nil
    }

    func setActiveUserId(_ userId: String?) {
        activeUserIdOverride = normalizedUserId(userId)
    }

    func migrateLegacyGlobalScopeIfNeeded(toUserId userId: String) {
        let normalizedId = normalizedUserId(userId)
        guard let normalizedId else { return }

        let progressScopedKey = "\(progressKey).\(normalizedId)"
        if defaults.string(forKey: progressScopedKey) == nil,
           let legacyProgress = defaults.string(forKey: progressKey) {
            defaults.set(legacyProgress, forKey: progressScopedKey)
        }

        let organizationScopedKey = "\(organizationDraftKey).\(normalizedId)"
        if defaults.data(forKey: organizationScopedKey) == nil,
           let legacyOrganizationDraft = defaults.data(forKey: organizationDraftKey) {
            defaults.set(legacyOrganizationDraft, forKey: organizationScopedKey)
        }

        let verificationScopedKey = "\(verificationMethodKey).\(normalizedId)"
        if defaults.string(forKey: verificationScopedKey) == nil,
           let legacyVerificationMethod = defaults.string(forKey: verificationMethodKey) {
            defaults.set(legacyVerificationMethod, forKey: verificationScopedKey)
        }

        let profileScopedKey = "\(profileDraftKey).\(normalizedId)"
        if keychain.load(key: profileScopedKey) == nil,
           let legacyProfileDraft = keychain.load(key: profileDraftKey) {
            keychain.save(key: profileScopedKey, data: legacyProfileDraft)
        }
    }

    func saveProgress(_ step: OnboardingStep) {
        defaults.set(step.rawValue, forKey: scopedDefaultsKey(progressKey))
    }

    func loadProgress() -> OnboardingStep? {
        guard let raw = defaults.string(forKey: scopedDefaultsKey(progressKey)) else { return nil }
        return OnboardingStep(rawValue: raw)
    }

    func clearProgress() {
        defaults.removeObject(forKey: scopedDefaultsKey(progressKey))
    }

    func saveProfileDraft(_ draft: OnboardingProfileDraft) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(draft) else { return }
        keychain.save(key: scopedKeychainKey(profileDraftKey), data: data)
    }

    func loadProfileDraft() -> OnboardingProfileDraft? {
        guard let data = keychain.load(key: scopedKeychainKey(profileDraftKey)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(OnboardingProfileDraft.self, from: data)
    }

    func clearProfileDraft() {
        keychain.delete(key: scopedKeychainKey(profileDraftKey))
    }

    func saveOrganizationDraft(_ draft: OnboardingOrganizationDraft) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(draft) else { return }
        defaults.set(data, forKey: scopedDefaultsKey(organizationDraftKey))
    }

    func loadOrganizationDraft() -> OnboardingOrganizationDraft? {
        guard let data = defaults.data(forKey: scopedDefaultsKey(organizationDraftKey)) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(OnboardingOrganizationDraft.self, from: data)
    }

    func clearOrganizationDraft() {
        defaults.removeObject(forKey: scopedDefaultsKey(organizationDraftKey))
    }

    func saveVerificationMethod(_ method: String) {
        defaults.set(method, forKey: scopedDefaultsKey(verificationMethodKey))
    }

    func loadVerificationMethod() -> String? {
        defaults.string(forKey: scopedDefaultsKey(verificationMethodKey))
    }

    func clearVerificationMethod() {
        defaults.removeObject(forKey: scopedDefaultsKey(verificationMethodKey))
    }

    func clearAll(forUserId userId: String) {
        clearProgress(forUserId: userId)
        clearProfileDraft(forUserId: userId)
        clearOrganizationDraft(forUserId: userId)
        clearVerificationMethod(forUserId: userId)
    }

    func clearLegacyGlobalScope() {
        defaults.removeObject(forKey: progressKey)
        keychain.delete(key: profileDraftKey)
        defaults.removeObject(forKey: organizationDraftKey)
        defaults.removeObject(forKey: verificationMethodKey)
    }

    func clearAll() {
        clearProgress()
        clearProfileDraft()
        clearOrganizationDraft()
        clearVerificationMethod()
    }

    private var activeUserId: String? {
        if let override = normalizedUserId(activeUserIdOverride) {
            return override
        }
        return normalizedUserId(userIdProvider())
    }

    private func scopedDefaultsKey(_ baseKey: String) -> String {
        guard let activeUserId else { return baseKey }
        return "\(baseKey).\(activeUserId)"
    }

    private func scopedKeychainKey(_ baseKey: String) -> String {
        guard let activeUserId else { return baseKey }
        return "\(baseKey).\(activeUserId)"
    }

    private func clearProgress(forUserId userId: String) {
        defaults.removeObject(forKey: "\(progressKey).\(userId)")
    }

    private func clearProfileDraft(forUserId userId: String) {
        keychain.delete(key: "\(profileDraftKey).\(userId)")
    }

    private func clearOrganizationDraft(forUserId userId: String) {
        defaults.removeObject(forKey: "\(organizationDraftKey).\(userId)")
    }

    private func clearVerificationMethod(forUserId userId: String) {
        defaults.removeObject(forKey: "\(verificationMethodKey).\(userId)")
    }

    private func normalizedUserId(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func defaultUserIdProvider() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
}
