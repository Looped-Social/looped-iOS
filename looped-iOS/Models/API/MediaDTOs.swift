import Foundation

struct MediaPresignRequestDTO: Encodable {
    let contentType: String
    let sizeBytes: Int
}

struct MediaPresignResponseDTO: Decodable {
    let key: String
    let uploadUrl: String
    let headers: [String: String]?
    let callbackSignature: String?
}

struct MediaCallbackRequestDTO: Encodable {
    let key: String
    let mimeType: String
    let width: Int
    let height: Int
    let durationSeconds: Int?
    let thumbnailMediaAssetId: Int?
}

struct MediaCallbackResponseDTO: Decodable {
    let id: Int
    let key: String
    let mimeType: String
    let cdnUrl: String?
    let thumbnailMediaAssetId: Int?
}

struct MediaResolveRequestDTO: Encodable {
    let ids: [Int]
}

struct MediaResolveResponseDTO: Decodable {
    let items: [MediaResolveItemDTO]
}

struct MediaResolveItemDTO: Decodable {
    let id: Int
    let key: String
    let mimeType: String
    let cdnUrl: String?
    let width: Int?
    let height: Int?
    let durationSeconds: Int?
    let thumbnailUrl: String?
    let thumbnailMediaAssetId: Int?
    let expiresAt: Date?
    let ttlSeconds: Int?
    let thumbnailExpiresAt: Date?
    let thumbnailTtlSeconds: Int?
}
