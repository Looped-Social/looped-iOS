import Foundation
import CryptoKit
import DeviceCheck

protocol AppAttestServiceProtocol {
    func currentKeyId() async -> String?
    func prepareForAnonymousEnrollment(forceRefresh: Bool) async -> String?
}

actor AppAttestService: AppAttestServiceProtocol {
    private let apiClient: APIClient
    private let store: AppAttestStore
    private let deviceAttestClient: any DeviceAttestClientProtocol

    init(
        apiClient: APIClient = APIClient(),
        store: AppAttestStore = AppAttestStore(),
        deviceAttestClient: any DeviceAttestClientProtocol = AppleDeviceAttestClient()
    ) {
        self.apiClient = apiClient
        self.store = store
        self.deviceAttestClient = deviceAttestClient
    }

    func currentKeyId() async -> String? {
        store.loadKeyId()
    }

    func prepareForAnonymousEnrollment(forceRefresh: Bool = false) async -> String? {
        if !forceRefresh, let existing = store.loadKeyId() {
            return existing
        }
        guard deviceAttestClient.isSupported else {
            return nil
        }

        do {
            let challengeRequest = AppAttestChallengeRequestDTO()
            let challenge: AppAttestChallengeResponseDTO = try await apiClient.post(
                "/v1/devices/app-attest/challenge",
                body: challengeRequest
            )
            guard challenge.mode != "disabled", challenge.enabled != false else {
                return nil
            }
            guard let challengeId = challenge.challengeId,
                  let challengeValue = challenge.challenge,
                  let challengeData = Data(base64URLEncoded: challengeValue) else {
                return nil
            }

            let clientDataHash = Data(SHA256.hash(data: challengeData))
            let keyId = try await deviceAttestClient.generateKey()
            let attestationObject = try await deviceAttestClient.attestKey(
                keyId: keyId,
                clientDataHash: clientDataHash
            )
            let assertionObject = try? await deviceAttestClient.generateAssertion(
                keyId: keyId,
                clientDataHash: clientDataHash
            )
            let completeRequest = AppAttestCompleteRequestDTO(
                challengeId: challengeId,
                keyId: keyId,
                attestationObject: attestationObject.base64EncodedString(),
                assertionObject: assertionObject?.base64EncodedString()
            )
            let _: AppAttestCompleteResponseDTO = try await apiClient.post(
                "/v1/devices/app-attest/complete",
                body: completeRequest
            )

            store.saveKeyId(keyId)
            return keyId
        } catch {
            return nil
        }
    }
}

protocol DeviceAttestClientProtocol {
    var isSupported: Bool { get }
    func generateKey() async throws -> String
    func attestKey(keyId: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(keyId: String, clientDataHash: Data) async throws -> Data
}

struct AppleDeviceAttestClient: DeviceAttestClientProtocol {
    private let service = DCAppAttestService.shared

    var isSupported: Bool {
        service.isSupported
    }

    func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            service.generateKey { keyId, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let keyId else {
                    continuation.resume(throwing: AppAttestClientError.missingKeyId)
                    return
                }
                continuation.resume(returning: keyId)
            }
        }
    }

    func attestKey(keyId: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.attestKey(keyId, clientDataHash: clientDataHash) { attestationObject, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let attestationObject else {
                    continuation.resume(throwing: AppAttestClientError.missingAttestationObject)
                    return
                }
                continuation.resume(returning: attestationObject)
            }
        }
    }

    func generateAssertion(keyId: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            service.generateAssertion(keyId, clientDataHash: clientDataHash) { assertionObject, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let assertionObject else {
                    continuation.resume(throwing: AppAttestClientError.missingAssertionObject)
                    return
                }
                continuation.resume(returning: assertionObject)
            }
        }
    }
}

private enum AppAttestClientError: Error {
    case missingKeyId
    case missingAttestationObject
    case missingAssertionObject
}

private extension Data {
    init?(base64URLEncoded value: String) {
        let normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded: String
        switch normalized.count % 4 {
        case 2:
            padded = normalized + "=="
        case 3:
            padded = normalized + "="
        default:
            padded = normalized
        }
        self.init(base64Encoded: padded)
    }
}
