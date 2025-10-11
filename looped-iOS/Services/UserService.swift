import Foundation

class UserService: UserServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func getCurrentUser() async throws -> User {
        return try await apiClient.get("/users/me")
    }
    
    func updateProfile(displayName: String?, bio: String?, isAnonymous: Bool) async throws -> User {
        let request = UpdateProfileRequest(displayName: displayName, bio: bio, isAnonymous: isAnonymous)
        return try await apiClient.put("/users/me", body: request)
    }
    
    func verifyEmployment(verification: EmploymentVerification) async throws {
        let _: EmptyResponse = try await apiClient.post("/users/verify-employment", body: verification)
    }
}

private struct UpdateProfileRequest: Codable {
    let displayName: String?
    let bio: String?
    let isAnonymous: Bool
}