import SwiftUI

struct PollCard: View {
    let poll: Poll
    let onPollUpdate: (Poll) -> Void
    private let pollsService: PollsServiceProtocol

    @State private var currentPoll: Poll
    @State private var selectedOptionId: Int?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var queuedOptionId: Int?

    init(
        poll: Poll,
        pollsService: PollsServiceProtocol = PollsService(),
        onPollUpdate: @escaping (Poll) -> Void
    ) {
        self.poll = poll
        self.pollsService = pollsService
        self.onPollUpdate = onPollUpdate
        _currentPoll = State(initialValue: poll)
        _selectedOptionId = State(initialValue: poll.viewer?.selectedOptionIds.first)
    }

    private var canChangeVote: Bool {
        (currentPoll.viewer?.canChangeVote ?? false) && currentPoll.isOpen
    }

    private var shouldShowResults: Bool {
        (currentPoll.viewer?.hasVoted ?? false) || !currentPoll.isOpen
    }

    private let maxSelections = 1

    private var votesLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: currentPoll.totalVotes)) ?? "\(currentPoll.totalVotes)"
        return "\(formatted) vote\(currentPoll.totalVotes == 1 ? "" : "s")"
    }

    private var statusLabel: String {
        guard let closesAt = currentPoll.closesAt else {
            return currentPoll.isOpen ? "No end" : "Final results"
        }
        if Date() >= closesAt { return "Final results" }
        let remaining = closesAt.timeIntervalSince(Date())
        if remaining < 3600 {
            let minutes = max(1, Int(remaining / 60))
            return "Ends in \(minutes)m"
        }
        if remaining < 86400 {
            let hours = max(1, Int(remaining / 3600))
            return "Ends in \(hours)h"
        }
        let days = max(1, Int(remaining / 86400))
        return "Ends in \(days)d"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentPoll.question)
                .font(.loopedBodyStrong)
                .foregroundColor(.loopedTextPrimary)

            VStack(spacing: 10) {
                ForEach(currentPoll.options) { option in
                    PollOptionRow(
                        option: option,
                        isSelected: selectedOptionId == option.id,
                        showsResults: shouldShowResults,
                        accentColor: .loopedPrimary
                    ) {
                        guard currentPoll.isOpen else { return }
                        guard canChangeVote || !(currentPoll.viewer?.hasVoted ?? false) else { return }
                        guard selectedOptionId != option.id else { return }
                        errorMessage = nil
                        selectedOptionId = option.id
                        Task { await submitVote(optionId: option.id) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            HStack(spacing: 8) {
                Text(votesLabel)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                Text("•")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                Text(statusLabel)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                if isSubmitting {
                    Text("•")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                    Text("Updating…")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                }
                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedError)
            }

            if currentPoll.isOpen {
                Text("Pick one")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .onChange(of: poll.updatedAt) { _, _ in
            syncFromParent()
        }
        .onChange(of: poll.totalVotes) { _, _ in
            syncFromParent()
        }
        .onChange(of: poll.viewer?.selectedOptionIds) { _, _ in
            syncFromParent()
        }
    }

    private func syncFromParent() {
        currentPoll = poll
        if let selected = poll.viewer?.selectedOptionIds.first {
            selectedOptionId = selected
        }
    }

    @MainActor
    private func submitVote(optionId: Int) async {
        guard currentPoll.isOpen else { return }

        if isSubmitting {
            queuedOptionId = optionId
            return
        }

        isSubmitting = true
        queuedOptionId = nil
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let updated = try await pollsService.vote(
                pollId: currentPoll.id,
                selectedOptionIds: [optionId]
            )
            currentPoll = updated
            selectedOptionId = updated.viewer?.selectedOptionIds.first ?? optionId
            onPollUpdate(updated)
        } catch {
            errorMessage = error.localizedDescription
        }

        if let queuedOptionId {
            self.queuedOptionId = nil
            await submitVote(optionId: queuedOptionId)
        }
    }
}

private struct PollOptionRow: View {
    let option: PollOption
    let isSelected: Bool
    let showsResults: Bool
    let accentColor: Color
    let onTap: () -> Void

    private var percentText: String {
        let value = max(0, min(option.votePercent, 100))
        if value == 0 { return "0%" }
        return String(format: "%.1f%%", value)
            .replacingOccurrences(of: ".0%", with: "%")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                pill
                if showsResults {
                    Text(percentText)
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(isSelected ? accentColor : .loopedTextSecondary)
                        .frame(minWidth: 54, alignment: .trailing)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var pill: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.loopedTextSecondary.opacity(0.08))

                if showsResults, option.votePercent > 0 {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(barFillColor)
                        .frame(width: max(0, geo.size.width * CGFloat(option.votePercent / 100.0)))
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.10))
                }

                Text(option.text)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(isSelected ? accentColor : .loopedTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected && !showsResults ? accentColor.opacity(0.55) : Color.loopedClear, lineWidth: 1)
            )
        }
        .frame(minHeight: 44)
    }

    private var barFillColor: Color {
        if isSelected {
            return accentColor.opacity(0.22)
        }
        return Color.loopedTextSecondary.opacity(0.14)
    }
}
