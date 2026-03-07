import Foundation

struct UserNotice: Identifiable, Equatable, Codable {
    let key: String
    let title: String
    let body: String
    let dismissible: Bool
    let ctaLabel: String?

    var id: String { key }

    init(
        key: String,
        title: String,
        body: String,
        dismissible: Bool,
        ctaLabel: String?
    ) {
        self.key = key
        self.title = title
        self.body = body
        self.dismissible = dismissible
        self.ctaLabel = ctaLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum UserNoticeAckAction: String, Codable {
    case dismiss
    case cta
}

extension UserNotice {
    init(dto: UserNoticeDTO) {
        self.init(
            key: dto.key,
            title: dto.title,
            body: dto.body,
            dismissible: dto.dismissible ?? true,
            ctaLabel: dto.ctaLabel
        )
    }
}
