import Foundation

struct ProfileCompletionDTO: Codable {
    let shouldPrompt: Bool?
    let missingPhoto: Bool?
    let missingBio: Bool?
    let missingSpecialization: Bool?
    let dismissedAt: Date?
    let completedAt: Date?
}

struct ProfileCompletionResponseDTO: Codable {
    let profileCompletion: ProfileCompletionDTO?
}
