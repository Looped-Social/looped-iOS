import Foundation

final class MessageMediaService: MessageMediaServiceProtocol {
    private let apiClient: APIClient
    private let session: URLSession

    init(apiClient: APIClient = APIClient(), session: URLSession = .shared) {
        self.apiClient = apiClient
        self.session = session
    }

    func uploadImage(data: Data, mimeType: String) async throws -> String {
        try await upload(data: data, fileURL: nil, mimeType: mimeType)
    }

    func uploadVideo(fileURL: URL, mimeType: String) async throws -> String {
        try await upload(data: nil, fileURL: fileURL, mimeType: mimeType)
    }

    func resolve(keys: [String]) async throws -> [MessageMediaResolvedItem] {
        let deduped = Array(Set(keys)).sorted()
        guard !deduped.isEmpty else { return [] }

        var resolved: [MessageMediaResolvedItem] = []
        resolved.reserveCapacity(deduped.count)

        var index = 0
        while index < deduped.count {
            let end = min(index + 50, deduped.count)
            let chunk = Array(deduped[index..<end])
            let request = MessageMediaResolveRequestDTO(keys: chunk)
            let dto: MessageMediaResolveResponseDTO = try await apiClient.post(
                "/v1/message-media/resolve",
                body: request
            )
            let now = Date()
            resolved.append(contentsOf: dto.items.map { item in
                let expiresAt = now.addingTimeInterval(TimeInterval(item.expiresInSeconds ?? 300))
                return MessageMediaResolvedItem(
                    key: item.key,
                    downloadUrl: item.downloadUrl,
                    mimeType: item.mimeType,
                    expiresAt: expiresAt
                )
            })
            index = end
        }

        return resolved
    }

    private func upload(data: Data?, fileURL: URL?, mimeType: String) async throws -> String {
        let sizeBytes = data?.count ?? fileSizeBytes(fileURL)
        let request = MessageMediaPresignRequestDTO(contentType: mimeType, sizeBytes: sizeBytes)
        let presign: MessageMediaPresignResponseDTO = try await apiClient.post(
            "/v1/message-media/presign",
            body: request
        )

        try await uploadToPresignedUrl(
            data: data,
            fileURL: fileURL,
            uploadUrl: presign.uploadUrl,
            headers: presign.headers ?? [:],
            mimeType: mimeType
        )
        return presign.key
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
