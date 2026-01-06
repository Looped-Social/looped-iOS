import Foundation

struct DisplayCommunity: Codable, Equatable {
    let id: Int
    let name: String
    let kind: CommunityKind
    let specializationType: CommunitySpecializationType?

    var displayText: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? "Community" : trimmed
        return resolved
    }

    var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}

extension DisplayCommunity {
    init(dto: DisplayCommunityDTO) {
        id = dto.id
        name = dto.name
        kind = CommunityKind(rawValue: dto.kind ?? "") ?? .unknown
        specializationType = CommunitySpecializationType(rawValue: dto.specializationType ?? "")
    }

    init(verification: CommunityVerification) {
        id = verification.communityId
        name = verification.communityName
        kind = verification.communityKind
        specializationType = nil
    }
}
