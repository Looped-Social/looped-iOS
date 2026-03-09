import Foundation

struct SpecializationIndexItem: Identifiable, Equatable {
    let id: Int
    let name: String
    let shortName: String?
    let bannerImageUrl: String?
    let iconImageUrl: String?
    let icon: CommunityIcon?

    var preferredSpecializationIcon: CommunityIcon? {
        CommunityIcon.imageURL(iconImageUrl) ?? icon?.normalizedOrNil()
    }
}

extension SpecializationIndexItem {
    init(dto: SpecializationIndexItemDTO) {
        id = dto.id
        name = dto.name
        shortName = dto.shortName
        bannerImageUrl = dto.bannerImageUrl
        iconImageUrl = dto.iconImageUrl
        icon = dto.icon?.normalizedOrNil()
    }
}
