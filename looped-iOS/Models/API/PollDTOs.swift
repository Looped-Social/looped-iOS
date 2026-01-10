import Foundation

struct PollDTO: Codable {
    let id: Int
    let postId: Int
    let question: String
    let maxSelections: Int
    let closesAt: Date?
    let status: PollStatus
    let options: [PollOptionDTO]
    let totalVotes: Int
    let viewer: PollViewerDTO?
    let updatedAt: Date?
}

struct PollOptionDTO: Codable {
    let id: Int
    let text: String
    let voteCount: Int
    let votePercent: Double
}

struct PollViewerDTO: Codable {
    let hasVoted: Bool
    let selectedOptionIds: [Int]
    let canChangeVote: Bool
}

struct CreatePostPollRequestDTO: Codable {
    let question: String
    let options: [String]
    let maxSelections: Int?
    let closesAt: String?
}

struct PollVoteRequestDTO: Codable {
    let selectedOptionIds: [Int]
}

