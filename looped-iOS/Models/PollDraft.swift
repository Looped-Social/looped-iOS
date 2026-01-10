import Foundation

struct PollDraft: Codable, Equatable {
    var question: String
    var options: [String]
    var maxSelections: Int
    var closesAt: Date?

    init(
        question: String = "",
        options: [String] = ["", ""],
        maxSelections: Int = 1,
        closesAt: Date? = nil
    ) {
        self.question = question
        self.options = options
        self.maxSelections = maxSelections
        self.closesAt = closesAt
    }

    var normalizedOptions: [String] {
        options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var hasDuplicateOptions: Bool {
        let normalized = normalizedOptions.map { $0.lowercased() }
        return Set(normalized).count != normalized.count
    }

    var isValid: Bool {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else { return false }
        let normalized = normalizedOptions
        guard normalized.count >= 2, normalized.count <= 20 else { return false }
        guard !hasDuplicateOptions else { return false }
        // Client UX is single-choice; backend enforces this too.
        guard maxSelections == 1 else { return false }
        if let closesAt {
            return Date() < closesAt
        }
        return true
    }
}
