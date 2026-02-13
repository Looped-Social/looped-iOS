import Foundation

enum CommunityRequestKind: String {
    case company
    case school
    case field
    case major
    case unknown
}

enum CommunityRequestStatus: String {
    case pending
    case approved
    case rejected
    case unknown
}

struct CommunityRequest: Identifiable {
    let id: Int
    let name: String
    let about: String?
    let kind: CommunityRequestKind
    let status: CommunityRequestStatus
    let imageKey: String?
    let imageUrl: String?
}

struct CommunityRequestSubmission {
    let id: Int
    let status: CommunityRequestStatus
}

extension CommunityRequest {
    init(dto: CommunityRequestDTO) {
        id = dto.id
        name = dto.name ?? ""
        about = dto.about ?? dto.description
        let kindValue = dto.kind ?? dto.type ?? ""
        kind = CommunityRequestKind(rawValue: kindValue) ?? .unknown
        status = CommunityRequestStatus(rawValue: dto.status ?? "") ?? .unknown
        imageKey = dto.imageKey
        imageUrl = dto.imageUrl
    }
}
