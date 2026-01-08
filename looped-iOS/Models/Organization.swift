import Foundation

struct Organization: Identifiable {
    let id: UUID
    let backendId: Int?
    let name: String
    let category: String
    let logoText: String
    let kind: OrganizationKind

    init(
        id: UUID? = nil,
        backendId: Int? = nil,
        name: String,
        category: String,
        logoText: String,
        kind: OrganizationKind = .company
    ) {
        self.backendId = backendId
        self.id = backendId.map(UUID.fromBackendId) ?? (id ?? UUID())
        self.name = name
        self.category = category
        self.logoText = logoText
        self.kind = kind
    }
}

enum OrganizationKind: String {
    case company
    case school
}

extension Organization {
    init(community: CommunitySearchResult) {
        let orgKind: OrganizationKind
        switch community.kind {
        case .school:
            orgKind = .school
        case .company:
            orgKind = .company
        default:
            orgKind = .company
        }

        self.init(
            backendId: community.id,
            name: community.name,
            category: "",
            logoText: Self.logoText(for: community.name),
            kind: orgKind
        )
    }

    static func logoText(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "•" }
        let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "&" })
        let letters = parts.prefix(4).compactMap(\.first)
        if letters.isEmpty, let first = trimmed.first {
            return String(first).uppercased()
        }
        return letters.map { String($0).uppercased() }.joined()
    }
}
