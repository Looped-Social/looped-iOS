import Foundation

struct CommunityRequestCreateRequestDTO: Encodable {
    let type: String
    let name: String
    let about: String
    let imageKey: String?
}

struct CommunityRequestCreateResponseDTO: Decodable {
    let id: Int
    let status: String
}

struct CommunityRequestDTO: Decodable {
    let id: Int
    let name: String?
    let about: String?
    let description: String?
    let type: String?
    let kind: String?
    let status: String?
    let imageKey: String?
    let imageUrl: String?
}

struct CommunityRequestListDTO: Decodable {
    let items: [CommunityRequestDTO]
    let nextCursor: String?

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            items = try container.decodeIfPresent([CommunityRequestDTO].self, forKey: .items) ?? []
            nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
            return
        }

        var container = try decoder.unkeyedContainer()
        var decodedItems: [CommunityRequestDTO] = []
        while !container.isAtEnd {
            decodedItems.append(try container.decode(CommunityRequestDTO.self))
        }
        items = decodedItems
        nextCursor = nil
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case nextCursor
    }
}
