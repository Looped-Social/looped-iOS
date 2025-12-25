import Foundation

struct ViolationsResponseDTO: Codable {
    let items: [ViolationDTO]
    let nextCursor: String?
}

struct ViolationDTO: Codable {
    let targetType: String
    let targetId: Int
    let reason: String
    let status: String
    let createdAt: Date
}
