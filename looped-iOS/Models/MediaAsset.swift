import Foundation

struct MediaAsset: Identifiable {
    let id: Int
    let key: String
    let mimeType: String
    let cdnUrl: String?
}

extension MediaAsset {
    init(dto: MediaCallbackResponseDTO) {
        id = dto.id
        key = dto.key
        mimeType = dto.mimeType
        cdnUrl = dto.cdnUrl
    }
}
