import Foundation

struct SpecializationJoinLimitListResponseDTO: Codable {
    let items: [SpecializationJoinLimitDTO]
}

struct SpecializationJoinLimitDTO: Codable {
    let specializationType: String
    let limit: Int
    let joinedCount: Int
    let remaining: Int
    let cooldownMonths: Int
    let cooldownActive: Bool
    let cooldownEndsAt: Date?
    let cooldownDaysRemaining: Int?
    let canJoin: Bool
    let blockedReason: String?
    let requiredVerificationKind: String?
    let joinRequiresVerificationKind: String?
    let joinBlockedReason: String?
}
