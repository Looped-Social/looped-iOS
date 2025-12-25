import Foundation

struct Violation: Identifiable {
    let id: UUID
    let targetType: ViolationTargetType
    let targetId: Int
    let reason: String
    let status: ViolationStatus
    let createdAt: Date

    init(dto: ViolationDTO) {
        self.id = UUID()
        self.targetType = ViolationTargetType(rawValue: dto.targetType) ?? .unknown
        self.targetId = dto.targetId
        self.reason = dto.reason
        self.status = ViolationStatus(rawValue: dto.status) ?? .unknown
        self.createdAt = dto.createdAt
    }
}

enum ViolationTargetType: String {
    case postRemoval = "post_removal"
    case userBan = "user_ban"
    case unknown
}

enum ViolationStatus: String {
    case removed
    case active
    case unknown
}

extension Violation {
    var title: String {
        switch targetType {
        case .postRemoval:
            return "Post removed"
        case .userBan:
            return "Account banned"
        case .unknown:
            return "Violation"
        }
    }

    var subtitle: String {
        switch targetType {
        case .postRemoval:
            return "Post ID \(targetId)"
        case .userBan:
            return "Ban ID \(targetId)"
        case .unknown:
            return "ID \(targetId)"
        }
    }

    var statusText: String {
        switch status {
        case .removed:
            return "Removed"
        case .active:
            return "Active"
        case .unknown:
            return "Unknown"
        }
    }

    var canAppeal: Bool {
        targetType == .postRemoval || targetType == .userBan
    }

    var appealTargetType: String {
        switch targetType {
        case .postRemoval:
            return "post_removal"
        case .userBan:
            return "user_ban"
        case .unknown:
            return "unknown"
        }
    }
}
