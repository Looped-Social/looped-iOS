import Foundation

final class PhotoIdVerificationService: PhotoIdVerificationServiceProtocol {
    private let apiClient: APIClient
    private let urlSession: URLSession

    init(apiClient: APIClient = APIClient(), urlSession: URLSession = .shared) {
        self.apiClient = apiClient
        self.urlSession = urlSession
    }

    func start() async throws -> PhotoIdVerificationStartResponse {
        let dto: PhotoIdVerificationStartResponseDTO = try await apiClient.post(
            "/v1/verification/photo-id/start",
            body: EmptyResponse(),
            requiresAuth: true
        )

        return PhotoIdVerificationStartResponse(
            status: dto.status,
            method: dto.method,
            uploadSessionId: dto.uploadSessionId,
            required: dto.required.compactMap(PhotoIdDocumentKind.init(rawValue:)),
            optional: dto.optional.compactMap(PhotoIdDocumentKind.init(rawValue:)),
            constraints: PhotoIdVerificationConstraints(
                allowedContentTypes: dto.constraints.allowedContentTypes,
                maxBytes: dto.constraints.maxBytes
            )
        )
    }

    func presign(
        uploadSessionId: String,
        kind: PhotoIdDocumentKind,
        contentType: String,
        sizeBytes: Int
    ) async throws -> PhotoIdVerificationPresignResponse {
        let request = PhotoIdVerificationPresignRequestDTO(
            uploadSessionId: uploadSessionId,
            kind: kind.rawValue,
            contentType: contentType,
            sizeBytes: sizeBytes
        )
        let dto: PhotoIdVerificationPresignResponseDTO = try await apiClient.post(
            "/v1/verification/photo-id/presign",
            body: request,
            requiresAuth: true
        )

        guard let parsedKind = PhotoIdDocumentKind(rawValue: dto.kind) else {
            throw APIError.apiError(code: 400, error: "invalid_kind", message: "Unsupported document kind: \(dto.kind)")
        }
        guard let url = URL(string: dto.uploadUrl) else {
            throw APIError.apiError(code: 400, error: "invalid_upload_url", message: "Invalid upload URL returned.")
        }

        return PhotoIdVerificationPresignResponse(
            kind: parsedKind,
            key: dto.key,
            uploadUrl: url,
            headers: dto.headers
        )
    }

    func uploadDocument(
        uploadSessionId: String,
        kind: PhotoIdDocumentKind,
        data: Data,
        contentType: String
    ) async throws -> String {
        let presignResponse = try await presign(
            uploadSessionId: uploadSessionId,
            kind: kind,
            contentType: contentType,
            sizeBytes: data.count
        )

        var request = URLRequest(url: presignResponse.uploadUrl)
        request.httpMethod = "PUT"
        presignResponse.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await urlSession.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        return presignResponse.key
    }

    func submit(
        uploadSessionId: String,
        selfieKey: String,
        idFrontKey: String,
        idBackKey: String?
    ) async throws -> PhotoIdVerificationSubmitResponse {
        let request = PhotoIdVerificationSubmitRequestDTO(
            uploadSessionId: uploadSessionId,
            documents: PhotoIdVerificationDocumentsDTO(
                selfieKey: selfieKey,
                idFrontKey: idFrontKey,
                idBackKey: idBackKey
            )
        )

        let dto: PhotoIdVerificationSubmitResponseDTO = try await apiClient.post(
            "/v1/verification/photo-id/submit",
            body: request,
            requiresAuth: true
        )

        return PhotoIdVerificationSubmitResponse(
            verificationRequestId: dto.verificationRequestId,
            status: dto.status
        )
    }

    func status() async throws -> PhotoIdVerificationStatusResponse {
        let dto: PhotoIdVerificationStatusResponseDTO = try await apiClient.get(
            "/v1/verification/photo-id/status",
            requiresAuth: true
        )
        return PhotoIdVerificationStatusResponse(
            method: dto.method,
            status: PhotoIdVerificationStatus(rawValue: dto.status) ?? .unknown
        )
    }
}
