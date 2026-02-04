import Foundation

enum CommunityIconKind: String, Codable, Equatable {
    case emoji
    case sfSymbol = "sf_symbol"
    case imageUrl = "image_url"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = CommunityIconKind(rawValue: normalized) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let rawValue = self == .unknown ? "unknown" : self.rawValue
        try container.encode(rawValue)
    }
}

struct CommunityIcon: Codable, Equatable {
    let kind: CommunityIconKind
    let value: String
}

extension CommunityIcon {
    func normalizedOrNil() -> CommunityIcon? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard kind != .unknown, !trimmedValue.isEmpty else { return nil }
        return CommunityIcon(kind: kind, value: trimmedValue)
    }
}

