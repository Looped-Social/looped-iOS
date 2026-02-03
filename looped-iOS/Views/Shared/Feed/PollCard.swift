import SwiftUI

struct PollCard: View {
    let poll: Poll
    let communityId: Int?
    let communityName: String?
    let communityShortName: String?
    let communityKind: CommunityKind?
    let communityPermissions: CommunityPermissions?
    let onPollUpdate: (Poll) -> Void
    private let pollsService: PollsServiceProtocol
    private let communityService: CommunityServiceProtocol

    @State private var currentPoll: Poll
    @State private var selectedOptionId: Int?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var queuedOptionId: Int?
    @State private var localCommunityPermissions: CommunityPermissions?
    @State private var voteGate: VoteGate?
    @State private var actionError: PollActionError?
    @State private var isJoining = false
    @State private var verificationTargetCommunity: CommunityProfileData?

    init(
        poll: Poll,
        communityId: Int? = nil,
        communityName: String? = nil,
        communityShortName: String? = nil,
        communityKind: CommunityKind? = nil,
        communityPermissions: CommunityPermissions? = nil,
        pollsService: PollsServiceProtocol = PollsService(),
        communityService: CommunityServiceProtocol = CommunityService(),
        onPollUpdate: @escaping (Poll) -> Void
    ) {
        self.poll = poll
        self.communityId = communityId
        self.communityName = communityName
        self.communityShortName = communityShortName
        self.communityKind = communityKind
        self.communityPermissions = communityPermissions
        self.pollsService = pollsService
        self.communityService = communityService
        self.onPollUpdate = onPollUpdate
        _currentPoll = State(initialValue: poll)
        _selectedOptionId = State(initialValue: poll.viewer?.selectedOptionIds.first)
        _localCommunityPermissions = State(initialValue: communityPermissions)
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
                        handleOptionTap(optionId: option.id)
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
                if isJoining {
                    Text("•")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                    Text("Joining…")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                }
                Spacer()
            }

            voteGateView

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
        .sheet(item: $verificationTargetCommunity) { community in
            CommunityVerificationFlowView(community: community) {
                Task { await handleVerificationComplete(communityId: community.id) }
            }
        }
        .alert(item: $actionError) { error in
            if let action = error.primaryAction {
                return Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    primaryButton: .default(Text(action.buttonTitle)) {
                        handlePrimaryAction(action)
                    },
                    secondaryButton: .cancel()
                )
            }
            return Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
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

        if let gate = activeVoteGate {
            queuedOptionId = optionId
            presentGatePrompt(gate)
            return
        }

        selectedOptionId = optionId
        Task { await submitVote(optionId: optionId) }
    }

    @MainActor
    private func submitVote(optionId: Int) async {
        guard currentPoll.isOpen else { return }

        if isJoining {
            queuedOptionId = optionId
            return
        }

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
            voteGate = nil
            queuedOptionId = nil
            onPollUpdate(updated)
        } catch {
            selectedOptionId = currentPoll.viewer?.selectedOptionIds.first
            if let gate = gate(from: error) {
                voteGate = gate
                queuedOptionId = optionId
                presentGatePrompt(gate)
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

    private var activeVoteGate: VoteGate? {
        voteGate ?? gateFromPermissions
    }

    @ViewBuilder
    private var voteGateView: some View {
        if let gate = activeVoteGate {
            VStack(alignment: .leading, spacing: 10) {
                Text(gate.inlineMessage)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)

                if let actionTitle = gate.actionTitle, gate.isActionAvailable(communityId: communityId) {
                    Button(actionTitle) {
                        handleGateAction(gate)
                    }
                    .buttonStyle(.plain)
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedPrimary)
                    .disabled(isJoining || isSubmitting)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.loopedMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.loopedTextSecondary.opacity(0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func presentGatePrompt(_ gate: VoteGate) {
        actionError = PollActionError(
            title: gate.alertTitle,
            message: gate.inlineMessage,
            primaryAction: gate.primaryAction(communityId: communityId)
        )
    }

    private func handlePrimaryAction(_ action: PollActionError.PrimaryAction) {
        switch action {
        case .joinSpecialization:
            Task { await joinSpecializationAndRetryIfNeeded() }
        case .verifyCommunity:
            handleGateAction(.communityNotVerified)
        }
    }

    private func handleGateAction(_ gate: VoteGate) {
        switch gate {
        case .specializationNotJoined:
            Task { await joinSpecializationAndRetryIfNeeded() }
        case .communityNotVerified:
            startVerificationFlow()
        case .communityBanned:
            break
        }
    }

    private func startVerificationFlow() {
        guard let community = verificationCommunity else {
            actionError = PollActionError(
                title: "Verification needed",
                message: "You must be verified in this community to vote.",
                primaryAction: nil
            )
            return
        }
        verificationTargetCommunity = community
    }

    private var verificationCommunity: CommunityProfileData? {
        guard let communityId, communityId > 0 else { return nil }
        let trimmedName = (communityName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Community" : trimmedName
        let trimmedShortName = (communityShortName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedShortName = trimmedShortName.isEmpty ? nil : trimmedShortName
        return CommunityProfileData(
            id: communityId,
            name: resolvedName,
            shortName: resolvedShortName,
            description: "",
            kind: communityKind ?? .unknown,
            specializationType: .unknown,
            memberCount: 0,
            imageUrl: nil,
            isFollowing: false,
            isJoined: false,
            joinLimit: nil
        )
    }

    @MainActor
    private func joinSpecializationAndRetryIfNeeded() async {
        guard let communityId, communityId > 0 else { return }
        guard !isJoining else { return }
        isJoining = true
        errorMessage = nil

        do {
            try await communityService.joinSpecialization(id: communityId)
            NotificationCenter.default.post(
                name: .communityStateChanged,
                object: nil,
                userInfo: [LoopedNotificationUserInfoKey.communityId: communityId]
            )
            await CommunityPermissionsCache.shared.invalidate(communityId: communityId)
            localCommunityPermissions = await CommunityPermissionsCache.shared.permissions(communityId: communityId)
            voteGate = nil
            clearVoteGateIfResolved()
        } catch {
            isJoining = false
            actionError = PollActionError(
                title: "Couldn't join",
                message: joinErrorMessage(from: error),
                primaryAction: nil
            )
            return
        }

        isJoining = false
        if let queuedOptionId {
            self.queuedOptionId = nil
            await submitVote(optionId: queuedOptionId)
        }
    }

    @MainActor
    private func handleVerificationComplete(communityId: Int) async {
        await CommunityPermissionsCache.shared.invalidate(communityId: communityId)
        localCommunityPermissions = await CommunityPermissionsCache.shared.permissions(communityId: communityId)
        NotificationCenter.default.post(
            name: .communityStateChanged,
            object: nil,
            userInfo: [LoopedNotificationUserInfoKey.communityId: communityId]
        )
        voteGate = nil
        clearVoteGateIfResolved()

        if let queuedOptionId {
            self.queuedOptionId = nil
            await submitVote(optionId: queuedOptionId)
        }
    }

    private func clearVoteGateIfResolved() {
        guard let voteGate else { return }
        guard voteGate != .communityBanned else { return }
        guard localCommunityPermissions != nil else { return }
        if gateFromPermissions == nil {
            self.voteGate = nil
        }
    }

    private func gate(from error: Error) -> VoteGate? {
        guard case let APIError.apiError(code, apiError, _) = error else { return nil }
        guard code == 403 else { return nil }
        switch apiError {
        case "specialization_not_joined":
            return .specializationNotJoined
        case "community_not_verified":
            return .communityNotVerified
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
                return message ?? apiError
            default:
                return apiError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private func joinErrorMessage(from error: Error) -> String {
        if case let APIError.apiError(_, apiError, message) = error {
            switch apiError {
            case "specialization_verification_required":
                return message ?? "Verification is required to join."
            case "specialization_join_limit":
                return message ?? "You’ve reached the join limit."
            case "specialization_join_cooldown":
                return message ?? "You can’t change this right now."
            case "invalid_specialization":
                return message ?? "That specialization can't be joined."
            default:
                return message ?? apiError
            }
        }
        return error.localizedDescription
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

private enum VoteGate: Equatable {
    case specializationNotJoined
    case communityNotVerified
    case communityBanned

    var alertTitle: String {
        switch self {
        case .specializationNotJoined:
            return "Join required"
        case .communityNotVerified:
            return "Verification required"
        case .communityBanned:
            return "Unable to vote"
        }
    }

    var inlineMessage: String {
        switch self {
        case .specializationNotJoined:
            return "Join this major or field to vote in this poll."
        case .communityNotVerified:
            return "You must be verified in this community to vote in this poll."
        case .communityBanned:
            return "You can’t vote because you’re banned from this community."
        }
    }

    var actionTitle: String? {
        switch self {
        case .specializationNotJoined:
            return "Join"
        case .communityNotVerified:
            return "Verify"
        case .communityBanned:
            return nil
        }
    }

    func primaryAction(communityId: Int?) -> PollActionError.PrimaryAction? {
        switch self {
        case .specializationNotJoined:
            guard let communityId, communityId > 0 else { return nil }
            return .joinSpecialization
        case .communityNotVerified:
            guard let communityId, communityId > 0 else { return nil }
            return .verifyCommunity
        case .communityBanned:
            return nil
        }
    }

    func isActionAvailable(communityId: Int?) -> Bool {
        primaryAction(communityId: communityId) != nil
    }
}

private struct PollActionError: Identifiable {
    enum PrimaryAction {
        case joinSpecialization
        case verifyCommunity

        var buttonTitle: String {
            switch self {
            case .joinSpecialization:
                return "Join"
            case .verifyCommunity:
                return "Verify"
            }
        }
    }

    let id = UUID()
    let title: String
    let message: String
    let primaryAction: PrimaryAction?
}
