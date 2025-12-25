import Foundation

struct Appeal: Identifiable {
    let id: Int
    let targetType: AppealTargetType
    let targetId: Int?
    let reason: String
    let status: AppealStatus
    let createdAt: Date
    let updatedAt: Date
    let reviewedAt: Date?
    let reviewedBy: Int?
    let reviewedReason: String?

    init(dto: AppealDTO) {
        self.id = dto.id
        self.targetType = AppealTargetType(rawValue: dto.targetType) ?? .unknown
        self.targetId = dto.targetId
        self.reason = dto.reason
        self.status = AppealStatus(rawValue: dto.status) ?? .unknown
        self.createdAt = dto.createdAt
        self.updatedAt = dto.updatedAt
        self.reviewedAt = dto.reviewedAt
        self.reviewedBy = dto.reviewedBy
        self.reviewedReason = dto.reviewedReason
    }
}

enum AppealTargetType: String {
    case userBan = "user_ban"
    case postRemoval = "post_removal"
    case unknown
}

enum AppealStatus: String {
    case open
    case approved
    case rejected
    case unknown
}

extension Appeal {
    var title: String {
        switch targetType {
        case .postRemoval:
            return "Post removal appeal"
        case .userBan:
            return "Account ban appeal"
        case .unknown:
            return "Appeal"
        }
    }

    var subtitle: String {
        switch targetType {
        case .postRemoval:
            return targetId.map { "Post ID \($0)" } ?? "Post removal"
        case .userBan:
            return targetId.map { "Ban ID \($0)" } ?? "Account ban"
        case .unknown:
            return "Appeal #\(id)"
        }
    }

    var statusText: String {
        switch status {
        case .open:
            return "Open"
        case .approved:
            return "Approved"
        case .rejected:
            return "Rejected"
        case .unknown:
            return "Unknown"
        }
    }
}
