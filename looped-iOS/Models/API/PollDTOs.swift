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
    let asAnon: Bool?
    let anonProfileId: Int?
    let anonCert: String?
    let anonCertKid: String?
    let anonSig: String?

    init(
        selectedOptionIds: [Int],
        asAnon: Bool? = nil,
        anonProfileId: Int? = nil,
        anonCert: String? = nil,
        anonCertKid: String? = nil,
        anonSig: String? = nil
    ) {
        self.selectedOptionIds = selectedOptionIds
        self.asAnon = asAnon
        self.anonProfileId = anonProfileId
        self.anonCert = anonCert
        self.anonCertKid = anonCertKid
        self.anonSig = anonSig
    }
}
