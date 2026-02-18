import SwiftUI

struct PollCard: View {
    let poll: Poll
    let communityId: Int?
    let communityName: String?
    let communityShortName: String?
    let communityKind: CommunityKind?
    let communityPermissions: CommunityPermissions?
    let viewerCapabilities: PostViewerCapabilities?
    let postBackendId: Int?
    let telemetryFeedContext: TelemetryFeedContext?
    let onPollUpdate: (Poll) -> Void
    private let pollsService: PollsServiceProtocol

    @State private var currentPoll: Poll
    @State private var selectedOptionId: Int?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var queuedOptionId: Int?
    @State private var localCommunityPermissions: CommunityPermissions?
    @State private var voteGate: VoteGate?

    init(
        poll: Poll,
        communityId: Int? = nil,
        communityName: String? = nil,
        communityShortName: String? = nil,
        communityKind: CommunityKind? = nil,
        communityPermissions: CommunityPermissions? = nil,
        viewerCapabilities: PostViewerCapabilities? = nil,
        postBackendId: Int? = nil,
        telemetryFeedContext: TelemetryFeedContext? = nil,
        pollsService: PollsServiceProtocol = PollsService(),
        onPollUpdate: @escaping (Poll) -> Void
    ) {
        self.poll = poll
        self.communityId = communityId
        self.communityName = communityName
        self.communityShortName = communityShortName
        self.communityKind = communityKind
        self.communityPermissions = communityPermissions
        self.viewerCapabilities = viewerCapabilities
        self.postBackendId = postBackendId
        self.telemetryFeedContext = telemetryFeedContext
        self.pollsService = pollsService
        self.onPollUpdate = onPollUpdate
        _currentPoll = State(initialValue: poll)
        _selectedOptionId = State(initialValue: poll.viewer?.selectedOptionIds.first)
        _localCommunityPermissions = State(initialValue: communityPermissions)
    }

    private var canChangeVote: Bool {
        (currentPoll.viewer?.canChangeVote ?? false) && currentPoll.isOpen
    }

    private var shouldShowResults: Bool {
        (currentPoll.viewer?.hasVoted ?? false) || !currentPoll.isOpen || activeVoteGate != nil
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
	                let shouldEmphasizeLeadingResult = shouldShowResults
	                    && !(currentPoll.viewer?.hasVoted ?? false)
	                    && currentPoll.totalVotes > 0
	                let leadingOptionId = shouldEmphasizeLeadingResult
	                    ? currentPoll.options.max(by: { $0.votePercent < $1.votePercent })?.id
	                    : nil
	                ForEach(currentPoll.options) { option in
                    PollOptionRow(
                        option: option,
                        isSelected: selectedOptionId == option.id,
                        isLeadingResult: option.id == leadingOptionId,
                        showsResults: shouldShowResults,
                        accentColor: .loopedPrimary
                    ) {
                        handleOptionTap(optionId: option.id)
                    }
                    .accessibilityElement(children: .combine)
                    .disabled(activeVoteGate != nil)
                }
            }

            HStack(spacing: 8) {
                if currentPoll.isOpen, let gate = activeVoteGate {
                    Text(voteGateFooterMessage(for: gate))
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("•")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                }

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

            if currentPoll.isOpen, activeVoteGate == nil {
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
        .onChange(of: communityPermissions) { _, newValue in
            localCommunityPermissions = newValue
            clearVoteGateIfResolved()
        }
    }

    private func syncFromParent() {
        currentPoll = poll
        selectedOptionId = poll.viewer?.selectedOptionIds.first
    }

    private func handleOptionTap(optionId: Int) {
        guard currentPoll.isOpen else { return }
        guard canChangeVote || !(currentPoll.viewer?.hasVoted ?? false) else { return }
        guard selectedOptionId != optionId else { return }
        errorMessage = nil

        if let activeVoteGate {
            trackBlockedVote(gate: activeVoteGate)
            return
        }

        selectedOptionId = optionId
        Task { await submitVote(optionId: optionId) }
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
                selectedOptionIds: [optionId],
                communityId: communityId
            )
            currentPoll = updated
            selectedOptionId = updated.viewer?.selectedOptionIds.first ?? optionId
            voteGate = nil
            queuedOptionId = nil
            onPollUpdate(updated)
        } catch {
            selectedOptionId = currentPoll.viewer?.selectedOptionIds.first
            if let gate = gate(from: error) {
                voteGate = gate
                queuedOptionId = nil
            } else {
                errorMessage = pollErrorMessage(for: error)
            }
        }

        if let queuedOptionId, activeVoteGate == nil {
            self.queuedOptionId = nil
            await submitVote(optionId: queuedOptionId)
        }
    }

    private var gateFromPermissions: VoteGate? {
        guard let localCommunityPermissions else { return nil }
        guard !localCommunityPermissions.canPost else { return nil }
        if localCommunityPermissions.requiresJoin { return .specializationNotJoined }
        if localCommunityPermissions.requiresVerification { return .communityNotVerified }
        return nil
    }

    private var gateFromViewerCapabilities: VoteGate? {
        guard let viewerCapabilities else { return nil }
        guard !(viewerCapabilities.canInteract && viewerCapabilities.canVote) else { return nil }
        switch viewerCapabilities.lockReason {
        case .specializationNotJoined:
            return .specializationNotJoined
        case .specializationVerificationRequired:
            return .specializationNotJoined
        case .communityNotVerified:
            return .communityNotVerified
        case .verificationExpired:
            return .verificationExpired
        case .communityBanned:
            return .communityBanned
        case .unknownRestriction, .none:
            return .unknownRestriction
        }
    }

    private var activeVoteGate: VoteGate? {
        voteGate ?? gateFromViewerCapabilities ?? gateFromPermissions
    }

    private var voteGateCommunityName: String? {
        let trimmedShortName = (communityShortName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedShortName.isEmpty { return trimmedShortName }
        let trimmedName = (communityName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { return trimmedName }
        return nil
    }

    private func voteGateFooterMessage(for gate: VoteGate) -> String {
        let name = voteGateCommunityName ?? "this community"
        switch gate {
        case .specializationNotJoined:
            return "Join \(name) to vote"
        case .communityNotVerified:
            if communityKind == .company || communityKind == .school {
                return "Verify in \(name) to vote"
            }
            return "Verify to vote"
        case .verificationExpired:
            return "Verification expired"
        case .communityBanned:
            return "Can’t vote (banned)"
        case .unknownRestriction:
            return "Can’t vote right now"
        }
    }

    private func clearVoteGateIfResolved() {
        guard viewerCapabilities == nil else { return }
        guard let voteGate else { return }
        guard voteGate != .communityBanned else { return }
        guard localCommunityPermissions != nil else { return }
        if gateFromPermissions == nil {
            self.voteGate = nil
        }
    }

    private func trackBlockedVote(gate: VoteGate) {
        guard let postBackendId else { return }
        Task {
            await TelemetryManager.shared.trackInteractionBlocked(
                postId: postBackendId,
                feed: telemetryFeedContext,
                action: .vote,
                lockReason: gate.telemetryLockReason
            )
        }
    }

    private func gate(from error: Error) -> VoteGate? {
        guard case let APIError.apiError(code, apiError, _) = error else { return nil }
        guard code == 403 else { return nil }
        switch apiError {
        case "specialization_not_joined":
            return .specializationNotJoined
        case "specialization_verification_required":
            return .specializationNotJoined
        case "community_not_verified":
            return .communityNotVerified
        case "verification_expired":
            return .verificationExpired
        case "community_banned":
            return .communityBanned
        default:
            return nil
        }
    }

    private func pollErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return "Please sign in again and try voting."
            case .apiError(_, let apiError, let message):
                if apiError == "invalid_anon_proof" {
                    return "Anonymous session expired. Turn anonymous mode off and back on, then try again."
                }
                if apiError == "issue_token_required" || apiError == "issue_token_invalid" {
                    return "Anonymous session expired. Turn anonymous mode off and back on, then try again."
                }
                return message ?? apiError
            default:
                return apiError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

private struct PollOptionRow: View {
    let option: PollOption
    let isSelected: Bool
    let isLeadingResult: Bool
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
	                        .foregroundColor((isSelected || isLeadingResult) ? accentColor : .loopedTextSecondary)
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
	                    .fill(Color.loopedTextSecondary.opacity(0.10))

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
	            return accentColor.opacity(0.38)
	        }
	        if isLeadingResult {
	            return accentColor.opacity(0.30)
	        }
	        return Color.loopedTextSecondary.opacity(0.24)
	    }
	}

private enum VoteGate: Equatable {
    case specializationNotJoined
    case communityNotVerified
    case verificationExpired
    case communityBanned
    case unknownRestriction

    var restrictionMessage: String {
        switch self {
        case .specializationNotJoined:
            return "Join this major or field to vote."
        case .communityNotVerified:
            return "Verify in this community to vote."
        case .verificationExpired:
            return "Your verification expired. Verify again to vote."
        case .communityBanned:
            return "You’re banned from this community."
        case .unknownRestriction:
            return "You can’t vote right now."
        }
    }

    var telemetryLockReason: String {
        switch self {
        case .specializationNotJoined:
            return PostViewerLockReason.specializationNotJoined.rawValue
        case .communityNotVerified:
            return PostViewerLockReason.communityNotVerified.rawValue
        case .verificationExpired:
            return PostViewerLockReason.verificationExpired.rawValue
        case .communityBanned:
            return PostViewerLockReason.communityBanned.rawValue
        case .unknownRestriction:
            return PostViewerLockReason.unknownRestriction.rawValue
        }
    }
}
