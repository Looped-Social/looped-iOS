import Foundation

final class DeviceService: DeviceServiceProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func registerDevice(apnsToken: String) async throws {
        let request = DeviceRegistrationRequest(apnsToken: apnsToken, platform: "ios")
        let _: DeviceRegistrationResponseDTO = try await apiClient.post("/v1/devices", body: request)
    }
}

private struct DeviceRegistrationRequest: Encodable {
    let apnsToken: String
    let platform: String
}

private struct DeviceRegistrationResponseDTO: Decodable {
    let id: Int
    let apnsToken: String
    let platform: String
}
