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
