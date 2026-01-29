import Foundation

class MediaService: MediaServiceProtocol {
    private let apiClient: APIClient
    private let session: URLSession

    init(apiClient: APIClient = APIClient(), session: URLSession = .shared) {
        self.apiClient = apiClient
        self.session = session
    }

    func uploadImage(data: Data, mimeType: String, width: Int, height: Int, actor: MediaUploadActor) async throws -> MediaAsset {
        try await uploadPublicMedia(
            data: data,
            fileURL: nil,
            mimeType: mimeType,
            width: width,
            height: height,
            durationSeconds: nil,
            actor: actor,
            thumbnailMediaAssetId: nil
        )
    }

    func uploadVideo(
        fileURL: URL,
        mimeType: String,
        width: Int,
        height: Int,
        durationSeconds: Int,
        actor: MediaUploadActor,
        thumbnailMediaAssetId: Int?
    ) async throws -> MediaAsset {
        try await uploadPublicMedia(
            data: nil,
            fileURL: fileURL,
            mimeType: mimeType,
            width: width,
            height: height,
            durationSeconds: durationSeconds,
            actor: actor,
            thumbnailMediaAssetId: thumbnailMediaAssetId
        )
    }

    func resolvePublicMedia(ids: [Int]) async throws -> [MediaAsset] {
        let deduped = Array(Set(ids)).sorted()
        guard !deduped.isEmpty else { return [] }
        var resolved: [MediaAsset] = []
        resolved.reserveCapacity(deduped.count)
        let shouldLog = ProcessInfo.processInfo.environment["LOOPED_LOG_MEDIA_RESOLVE"] == "1"

        var index = 0
        while index < deduped.count {
            let end = min(index + 50, deduped.count)
            let chunk = Array(deduped[index..<end])
            let request = MediaResolveRequestDTO(ids: chunk)
            let dto: MediaResolveResponseDTO
            do {
                dto = try await apiClient.post(
                    "/v1/media/resolve",
                    body: request,
                    requiresAuth: true
                )
            } catch let error as APIError {
                guard case .unauthorized = error else { throw error }
                dto = try await apiClient.post(
                    "/v1/media/resolve",
                    body: request,
                    requiresAuth: false
                )
            }
            if shouldLog {
                let summary = dto.items.map { item in
                    "\(item.id) \(item.mimeType) url=\((item.cdnUrl ?? "").isEmpty ? "nil" : "ok") thumb=\((item.thumbnailUrl ?? "").isEmpty ? "nil" : "ok")"
                }.joined(separator: ", ")
                print("Media resolve chunk=\(chunk.count) → items=\(dto.items.count) [\(summary)]")
            }
            resolved.append(contentsOf: dto.items.map(MediaAsset.init(dto:)))
            index = end
        }

        return resolved
    }

    private func uploadPublicMedia(
        data: Data?,
        fileURL: URL?,
        mimeType: String,
        width: Int,
        height: Int,
        durationSeconds: Int?,
        actor: MediaUploadActor,
        thumbnailMediaAssetId: Int?
    ) async throws -> MediaAsset {
        let presignRequest = MediaPresignRequestDTO(
            contentType: mimeType,
            sizeBytes: data?.count ?? fileSizeBytes(fileURL)
        )
        let presign: MediaPresignResponseDTO = try await apiClient.post(
            "/v1/media/presign",
            body: presignRequest,
            requiresAuth: false
        )

        try await uploadToPresignedUrl(
            data: data,
            fileURL: fileURL,
            uploadUrl: presign.uploadUrl,
            headers: presign.headers ?? [:],
            mimeType: mimeType
        )

        let callbackRequest = MediaCallbackRequestDTO(
            key: presign.key,
            mimeType: mimeType,
            width: width,
            height: height,
            durationSeconds: durationSeconds,
            thumbnailMediaAssetId: thumbnailMediaAssetId
        )
        var callbackHeaders: [String: String] = [:]
        if let signature = presign.callbackSignature, !signature.isEmpty {
            callbackHeaders["X-Media-Signature"] = signature
        }
        if actor == .anon {
            callbackHeaders["X-Actor"] = "anon"
        }
        let callback: MediaCallbackResponseDTO = try await apiClient.post(
            "/v1/media/callback",
            body: callbackRequest,
            requiresAuth: actor == .user,
            headers: callbackHeaders
        )

        return MediaAsset(dto: callback)
    }

    private func uploadToPresignedUrl(
        data: Data?,
        fileURL: URL?,
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

        let response: URLResponse
        if let data {
            (_, response) = try await session.upload(for: request, from: data)
        } else if let fileURL {
            (_, response) = try await session.upload(for: request, fromFile: fileURL)
        } else {
            throw APIError.invalidResponse
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    private func fileSizeBytes(_ url: URL?) -> Int {
        guard let url else { return 0 }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize ?? 0
    }
}
