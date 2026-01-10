import Foundation

struct Poll: Codable, Equatable, Identifiable {
    let id: Int
    let postId: Int
    let question: String
    let maxSelections: Int
    let closesAt: Date?
    let status: PollStatus
    let options: [PollOption]
    let totalVotes: Int
    let viewer: PollViewer?
    let updatedAt: Date?

    var isOpen: Bool {
        if status != .open { return false }
        if let closesAt { return Date() < closesAt }
        return true
    }
}

enum PollStatus: String, Codable, Equatable {
    case open = "OPEN"
    case closed = "CLOSED"
    case unknown = "UNKNOWN"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = PollStatus(rawValue: value) ?? .unknown
    }
}

struct PollOption: Codable, Equatable, Identifiable {
    let id: Int
    let text: String
    let voteCount: Int
    let votePercent: Double
}

struct PollViewer: Codable, Equatable {
    let hasVoted: Bool
    let selectedOptionIds: [Int]
    let canChangeVote: Bool
}

extension Poll {
    init(dto: PollDTO) {
        self.init(
            id: dto.id,
            postId: dto.postId,
            question: dto.question,
            maxSelections: dto.maxSelections,
            closesAt: dto.closesAt,
            status: dto.status,
            options: dto.options.map(PollOption.init(dto:)),
            totalVotes: dto.totalVotes,
            viewer: dto.viewer.map(PollViewer.init(dto:)),
            updatedAt: dto.updatedAt
        )
    }
}

extension PollOption {
    init(dto: PollOptionDTO) {
        self.init(
            id: dto.id,
            text: dto.text,
            voteCount: dto.voteCount,
            votePercent: dto.votePercent
        )
    }
}

extension PollViewer {
    init(dto: PollViewerDTO) {
        self.init(
            hasVoted: dto.hasVoted,
            selectedOptionIds: dto.selectedOptionIds,
            canChangeVote: dto.canChangeVote
        )
    }
}

