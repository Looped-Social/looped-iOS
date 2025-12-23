import Foundation

struct UsernameAvailabilityResponseDTO: Codable {
    let username: String
    let available: Bool
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
