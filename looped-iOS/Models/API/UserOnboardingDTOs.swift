import Foundation

enum RemoteOnboardingStep: String, Codable {
    case profileSetup = "profile_setup"
    case selectCompany = "select_company"
    case verification = "verification"
    case verificationNotifications = "verification_notifications"
}

struct UsernameAvailabilityResponseDTO: Codable {
    let username: String
    let available: Bool
    let ownedByMe: Bool?
}

struct UserOnboardRequestDTO: Codable {
    let username: String
    let firstName: String
    let lastName: String
    let dateOfBirth: String
}

struct UserIdentityUpdateRequestDTO: Codable {
    let username: String
    let firstName: String
    let lastName: String
    let dateOfBirth: String
}

struct UserOnboardingStepUpdateRequestDTO: Codable {
    let step: RemoteOnboardingStep
}

struct OnboardingStateDTO: Codable {
    let onboardingComplete: Bool
    let onboardingStep: RemoteOnboardingStep
}

struct OnboardingContextV2DTO: Codable, Equatable {
    let selectedOrgId: Int?
    let selectedOrgName: String?
    let selectedOrgKind: String?
    let verificationPath: String?
    let verificationStatus: String?
    let specializationRequired: Bool?
    let specializationId: Int?
    let specializationName: String?
    let completionReason: String?
}

struct OnboardingStateV2DTO: Codable {
    let onboardingComplete: Bool
    let onboardingStep: RemoteOnboardingStep?
    let onboardingStageV2: String?
    let onboardingContext: OnboardingContextV2DTO?
}

struct OnboardingV2OrgRequestDTO: Codable {
    let orgId: Int
}

struct OnboardingV2VerificationChoiceRequestDTO: Codable {
    let verificationPath: String
}

struct OnboardingV2SpecializationRequestDTO: Codable {
    let specializationId: Int
}
