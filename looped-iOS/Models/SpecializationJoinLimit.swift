import Foundation

enum SpecializationJoinBlockedReason: String {
    case limit
    case cooldown
}

struct SpecializationJoinLimit: Equatable {
    let specializationType: CommunitySpecializationType
    let limit: Int
    let joinedCount: Int
    let remaining: Int
    let cooldownMonths: Int
    let cooldownActive: Bool
    let cooldownEndsAt: Date?
    let cooldownDaysRemaining: Int?
    let canJoin: Bool
    let blockedReason: SpecializationJoinBlockedReason?
}

extension SpecializationJoinLimit {
    init(dto: SpecializationJoinLimitDTO) {
        specializationType = CommunitySpecializationType(rawValue: dto.specializationType) ?? .unknown
        limit = dto.limit
        joinedCount = dto.joinedCount
        remaining = dto.remaining
        cooldownMonths = dto.cooldownMonths
        cooldownActive = dto.cooldownActive
        cooldownEndsAt = dto.cooldownEndsAt
        cooldownDaysRemaining = dto.cooldownDaysRemaining
        canJoin = dto.canJoin
        blockedReason = dto.blockedReason.flatMap(SpecializationJoinBlockedReason.init(rawValue:))
    }

    var pluralLabel: String {
        switch specializationType {
        case .major:
            return "Majors"
        case .department:
            return "Departments"
        case .unknown:
            return "Specializations"
        }
    }
}

