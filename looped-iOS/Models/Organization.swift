import Foundation

struct Organization: Identifiable {
    let id: UUID
    let name: String
    let category: String
    let logoText: String
    let kind: OrganizationKind

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        logoText: String,
        kind: OrganizationKind = .company
    ) {
        self.id = id
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
