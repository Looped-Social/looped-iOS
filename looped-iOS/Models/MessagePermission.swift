import Foundation

enum MessagePermission: String, CaseIterable, Identifiable, Codable {
    case all = "all"
    case company = "company"
    case following = "following"
    case noOne = "no_one"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .company:
            return "Company"
        case .following:
            return "Following"
        case .noOne:
            return "No One"
        }
    }

    var subtitle: String {
        switch self {
        case .all:
            return "Anyone can send you a request."
        case .company:
            return "Only people at your company can send requests."
        case .following:
            return "Only people you follow can send requests."
        case .noOne:
            return "No new message requests."
        }
    }
}
