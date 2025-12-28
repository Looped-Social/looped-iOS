import Foundation

class MediaService: MediaServiceProtocol {
    private let apiClient: APIClient
    private let session: URLSession

    init(apiClient: APIClient = APIClient(), session: URLSession = .shared) {
        self.apiClient = apiClient
        self.session = session
    }

    func uploadImage(data: Data, mimeType: String, width: Int, height: Int) async throws -> MediaAsset {
        let presignRequest = MediaPresignRequestDTO(
            contentType: mimeType,
            sizeBytes: data.count
        )
        let presign: MediaPresignResponseDTO = try await apiClient.post(
            "/v1/media/presign",
            body: presignRequest
        )

        try await uploadToPresignedUrl(
            data: data,
            uploadUrl: presign.uploadUrl,
            headers: presign.headers ?? [:],
            mimeType: mimeType
        )

        let callbackRequest = MediaCallbackRequestDTO(
            key: presign.key,
            mimeType: mimeType,
            width: width,
            height: height,
            durationSeconds: 0
        )
        let callback: MediaCallbackResponseDTO = try await apiClient.post(
            "/v1/media/callback",
            body: callbackRequest
        )

        return MediaAsset(dto: callback)
    }

    private func uploadToPresignedUrl(
        data: Data,
        uploadUrl: String,
        headers: [String: String],
        mimeType: String
    ) async throws {
        guard let url = URL(string: uploadUrl) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        let hasContentType = headers.keys.contains { $0.lowercased() == "content-type" }
        if !hasContentType {
            request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        }

        let (_, response) = try await session.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}
