import Foundation

struct Organization: Identifiable {
    let id: UUID
    let name: String
    let category: String
    let logoText: String

    init(id: UUID = UUID(), name: String, category: String, logoText: String) {
        self.id = id
        self.name = name
        self.category = category
        self.logoText = logoText
    }
}
