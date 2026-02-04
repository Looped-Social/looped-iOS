import Foundation

struct SpecializationIndexItem: Identifiable, Equatable {
    let id: Int
    let name: String
    let shortName: String?
    let icon: CommunityIcon?
}

extension SpecializationIndexItem {
    init(dto: SpecializationIndexItemDTO) {
        id = dto.id
        name = dto.name
        shortName = dto.shortName
        icon = dto.icon?.normalizedOrNil()
    }
}

