import Foundation

struct ContentPreferencesResponseDTO: Codable {
    let content: ContentPreferencesContentDTO
}

struct ContentPreferencesContentDTO: Codable {
    let hideAnonymousPosts: Bool
}

struct ContentPreferencesUpdateRequestDTO: Codable {
    let hideAnonymousPosts: Bool
}

