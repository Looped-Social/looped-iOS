import Foundation

struct MessageMediaPresignRequestDTO: Encodable {
    let contentType: String
    let sizeBytes: Int
}

struct MessageMediaPresignResponseDTO: Decodable {
    let key: String
    let uploadUrl: String
    let headers: [String: String]?
}

struct MessageMediaResolveRequestDTO: Encodable {
    let keys: [String]
}

struct MessageMediaResolveResponseDTO: Decodable {
    let items: [MessageMediaResolveItemDTO]
}

struct MessageMediaResolveItemDTO: Decodable {
    let key: String
    let downloadUrl: String
    let mimeType: String?
    let expiresInSeconds: Int?
}
