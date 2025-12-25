import Foundation

struct AppealsResponseDTO: Codable {
    let items: [AppealDTO]
}

struct AppealDTO: Codable {
    let id: Int
    let targetType: String
    let targetId: Int?
    let reason: String
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let reviewedAt: Date?
    let reviewedBy: Int?
    let reviewedReason: String?
}
