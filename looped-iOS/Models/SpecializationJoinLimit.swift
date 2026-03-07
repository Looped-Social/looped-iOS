import Foundation

enum SpecializationJoinBlockedReason: String, Codable {
    case limit
    case cooldown
    case verifyCompany = "verify_company"
    case verifySchool = "verify_school"
    case verificationRequired = "verification_required"
}

enum SpecializationJoinRequiresVerificationKind: String, Codable {
    case company
    case school

    var displayName: String {
        switch self {
        case .company:
            return "Company"
        case .school:
            return "Company"
        }
    }
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
    let joinRequiresVerificationKind: SpecializationJoinRequiresVerificationKind?
    let joinBlockedReason: SpecializationJoinBlockedReason?
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
        joinRequiresVerificationKind = (dto.joinRequiresVerificationKind ?? dto.requiredVerificationKind)
            .flatMap(SpecializationJoinRequiresVerificationKind.init(rawValue:))
        joinBlockedReason = dto.joinBlockedReason.flatMap(SpecializationJoinBlockedReason.init(rawValue:))
    }

    var pluralLabel: String {
        switch specializationType {
        case .major:
            return "Fields"
        case .field:
            return "Fields"
        case .unknown:
            return "Specializations"
        }
    }

    var requiresVerificationForJoin: Bool {
        joinBlockedReason == .verificationRequired || blockedReason == .verifyCompany || blockedReason == .verifySchool
    }

    var requiredVerificationKind: SpecializationJoinRequiresVerificationKind? {
        if let joinRequiresVerificationKind {
            return joinRequiresVerificationKind == .school ? .company : joinRequiresVerificationKind
        }
        switch blockedReason {
        case .verifyCompany:
            return .company
        case .verifySchool:
            return .company
        default:
            return nil
        }
    }
}
