import Foundation

struct ReportRequestDTO: Codable {
    let targetType: String
    let targetId: Int
    let reason: String
}

struct ReportResponseDTO: Codable {
    let id: Int?
}

struct AppealRequestDTO: Codable {
    let targetType: String
    let targetId: Int?
    let reason: String
}

struct AppealResponseDTO: Codable {
    let id: Int?
}
