import Foundation

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

final class OnboardingProgressStore {
    private let progressKey = "looped.onboarding.progress"
    private let profileDraftKey = "looped.onboarding.profileDraft"
    private let defaults: UserDefaults
    private let keychain: KeychainStore

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
    }

    var hasProgress: Bool {
        loadProgress() != nil
    }

    func saveProgress(_ step: OnboardingStep) {
        defaults.set(step.rawValue, forKey: progressKey)
    }

    func loadProgress() -> OnboardingStep? {
        guard let raw = defaults.string(forKey: progressKey) else { return nil }
        return OnboardingStep(rawValue: raw)
    }

    func clearProgress() {
        defaults.removeObject(forKey: progressKey)
    }

    func saveProfileDraft(_ draft: OnboardingProfileDraft) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(draft) else { return }
        keychain.save(key: profileDraftKey, data: data)
    }

    func loadProfileDraft() -> OnboardingProfileDraft? {
        guard let data = keychain.load(key: profileDraftKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(OnboardingProfileDraft.self, from: data)
    }

    func clearProfileDraft() {
        keychain.delete(key: profileDraftKey)
    }

    func clearAll() {
        clearProgress()
        clearProfileDraft()
    }
}
