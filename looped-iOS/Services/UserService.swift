import Foundation

class UserService: UserServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func getIdentity() async throws -> IdentityResponseDTO {
        try await apiClient.get("/v1/me")
    }
    
    func getCurrentUser() async throws -> User {
        let identity = try await getIdentity()
        guard let userDTO = identity.user else {
            throw UserServiceError.userNotProvisioned
        }
        return User(dto: userDTO, profile: userDTO.profile)
    }
    
    func getUser(by id: Int) async throws -> User {
        let dto: UserDTO = try await apiClient.get("/v1/users/\(id)")
        return User(dto: dto, profile: dto.profile)
    }
    
    func updateProfile(displayName: String?, bio: String?, isAnonymous: Bool) async throws -> User {
        let request = UpdateProfileRequest(displayName: displayName, bio: bio, isAnonymous: isAnonymous)
        return try await apiClient.put("/users/me", body: request)
    }
    
    func verifyEmployment(verification: EmploymentVerification) async throws {
        let _: EmptyResponse = try await apiClient.post("/users/verify-employment", body: verification)
    }
}

enum UserServiceError: Error, LocalizedError {
    case userNotProvisioned
    
    var errorDescription: String? {
        switch self {
        case .userNotProvisioned:
            return "Your account isn't fully onboarded yet."
        }
    }
}

private struct UpdateProfileRequest: Codable {
    let displayName: String?
    let bio: String?
    let isAnonymous: Bool
}
