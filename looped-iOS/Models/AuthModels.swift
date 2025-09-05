import Foundation

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let token: String
    let refreshToken: String
    let user: User
    let expiresAt: Date
}

struct RegistrationRequest: Codable {
    let email: String
    let password: String
    let username: String
    let company: String
    let employmentVerificationData: String
}

struct EmploymentVerification: Codable {
    let companyEmail: String
    let companyName: String
    let position: String?
    let verificationMethod: VerificationMethod
}

enum VerificationMethod: String, Codable {
    case email = "email"
    case linkedin = "linkedin"
    case companyDomain = "company_domain"
}