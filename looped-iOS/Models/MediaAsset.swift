import Foundation

struct MediaAsset: Identifiable {
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

extension MediaAsset {
    init(dto: MediaCallbackResponseDTO) {
        id = dto.id
        key = dto.key
        mimeType = dto.mimeType
        cdnUrl = dto.cdnUrl
        width = nil
        height = nil
        durationSeconds = nil
        thumbnailUrl = nil
        thumbnailMediaAssetId = dto.thumbnailMediaAssetId
        expiresAt = nil
        ttlSeconds = nil
        thumbnailExpiresAt = nil
        thumbnailTtlSeconds = nil
    }

    init(dto: MediaResolveItemDTO) {
        id = dto.id
        key = dto.key
        mimeType = dto.mimeType
        cdnUrl = dto.cdnUrl
        width = dto.width
        height = dto.height
        durationSeconds = dto.durationSeconds
        thumbnailUrl = dto.thumbnailUrl
        thumbnailMediaAssetId = dto.thumbnailMediaAssetId
        expiresAt = dto.expiresAt
        ttlSeconds = dto.ttlSeconds
        thumbnailExpiresAt = dto.thumbnailExpiresAt
        thumbnailTtlSeconds = dto.thumbnailTtlSeconds
    }
}
