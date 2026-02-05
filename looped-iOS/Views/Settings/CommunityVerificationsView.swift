import SwiftUI

struct CommunityVerificationsView: View {
    @StateObject private var viewModel = CommunityVerificationsViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedVerification: CommunityVerification?
    @State private var isShowingActions = false

    var body: some View {
        List {
            if !viewModel.joinLimits.isEmpty {
                Section("Specializations") {
                    ForEach(viewModel.joinLimits, id: \.specializationType) { limit in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(limit.pluralLabel)
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            Text(joinLimitSubtitle(limit))
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Joined Majors & Fields") {
                if viewModel.isLoading && viewModel.joinedSpecializations.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.loopedBackground)
                } else if viewModel.joinedSpecializations.isEmpty {
                    Text("None yet")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .listRowBackground(Color.loopedBackground)
                } else {
                    ForEach(viewModel.joinedSpecializations, id: \.id) { specialization in
                        HStack(spacing: 12) {
                            Text(specialization.displayText)
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            Spacer()

                            if let type = specialization.specializationType?.displayName {
                                Text(type)
                                    .font(.loopedSubBodyRegular)
                                    .foregroundColor(.loopedTextSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            verifiedEmailsSection

            Section {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.loopedBackground)
                } else if viewModel.items.isEmpty {
                    emptyState
                        .listRowBackground(Color.loopedBackground)
                } else {
                    ForEach(viewModel.items) { verification in
                        verificationRow(verification)
                    }
                }
            }
            header: {
                Text("Communities")
            } footer: {
                Text("Tap a verified community to unverify and release that email for another account.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    statusBanner(text: errorMessage, color: .loopedError)
                        .listRowBackground(Color.loopedBackground)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Verifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .confirmationDialog(
            selectedVerification?.communityName ?? "Verification",
            isPresented: $isShowingActions,
            titleVisibility: .visible
        ) {
            if let selectedVerification, selectedVerification.verified {
                Button("Unverify", role: .destructive) {
                    Task {
                        let didUnverify = await viewModel.unverify(communityId: selectedVerification.communityId)
                        if didUnverify {
                            await authViewModel.loadCurrentUser()
                        }
                    }
                }
                .disabled(viewModel.isUnverifying)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let selectedVerification {
                Text(
                    selectedVerification.isActive
                        ? "Unverifying removes your active verification and releases the email lock for this community."
                        : "Unverifying removes this verification from your account."
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.loopedCustom(size: 36))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No community verifications yet")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    @ViewBuilder
    private var verifiedEmailsSection: some View {
        Section("Verified Emails") {
            if viewModel.isLoading && viewModel.items.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.loopedBackground)
            } else if verifiedEmailItems.isEmpty {
                verifiedEmailsEmptyState
                    .listRowBackground(Color.loopedBackground)
            } else {
                ForEach(verifiedEmailItems) { verification in
                    verifiedEmailRow(verification)
                }
            }
        } footer: {
            Text("Only active email verifications appear here.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
    }

    private var verifiedEmailItems: [CommunityVerification] {
        viewModel.items
            .filter { $0.isActive }
            .filter { ($0.verifiedEmail?.isEmpty == false) }
            .sorted { $0.communityName.localizedCaseInsensitiveCompare($1.communityName) == .orderedAscending }
    }

    private var verifiedEmailsEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "envelope")
                .font(.loopedCustom(size: 34))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No verified emails yet")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            Text("Verify a community with your school/work email to see it here.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func verifiedEmailRow(_ verification: CommunityVerification) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verification.verifiedEmail ?? "")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .textSelection(.enabled)

                Text(verification.communityName)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            Text(statusText(for: verification))
                .font(.loopedSubBodyMedium)
                .foregroundColor(statusColor(for: verification))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor(for: verification).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private func verificationRow(_ verification: CommunityVerification) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verification.communityName)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                if viewModel.unverifyingCommunityId == verification.communityId {
                    ProgressView()
                        .tint(.loopedSecondary)
                }

                Text(statusText(for: verification))
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(statusColor(for: verification))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(for: verification).opacity(0.12))
                    .clipShape(Capsule())
            }

            if let method = verification.method {
                Text("Method: \(method.displayName)")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            if let verifiedEmail = verification.verifiedEmail, !verifiedEmail.isEmpty {
                Text("Verified email: \(verifiedEmail)")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .textSelection(.enabled)
            }

            if let expiryText = expiryText(for: verification) {
                Text(expiryText)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(verification.isExpired ? .loopedError : .loopedTextSecondary)
            }

            if verification.status == .rejected,
               let reason = verification.rejectReason?.trimmingCharacters(in: .whitespacesAndNewlines),
               !reason.isEmpty {
                Text(reason)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            if let helperText = helperText(for: verification) {
                Text(helperText)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard verification.verified else { return }
            selectedVerification = verification
            isShowingActions = true
        }
        .disabled(viewModel.isUnverifying)
    }

    private func expiryText(for verification: CommunityVerification) -> String? {
        if verification.status == .pending || verification.status == .rejected {
            return nil
        }
        guard let expiresAt = verification.expiresAt else {
            return verification.isExpired ? "Expired" : "Never expires"
        }
        let dateText = Self.expiryFormatter.string(from: expiresAt)
        return verification.isExpired ? "Expired \(dateText)" : "Expires \(dateText)"
    }

    private func statusText(for verification: CommunityVerification) -> String {
        switch verification.status {
        case .pending:
            return "Pending"
        case .rejected:
            return "Rejected"
        case .expired:
            return "Expired"
        case .active:
            return "Active"
        case .unknown:
            if !verification.verified {
                return "Pending"
            }
            if verification.isExpired || !verification.active {
                return "Expired"
            }
            return "Active"
        }
    }

    private func statusColor(for verification: CommunityVerification) -> Color {
        switch verification.status {
        case .pending:
            return .loopedSecondary
        case .rejected:
            return .loopedError
        case .expired:
            return .loopedError
        case .active:
            return .loopedPrimary
        case .unknown:
            if !verification.verified {
                return .loopedSecondary
            }
            if verification.isExpired || !verification.active {
                return .loopedError
            }
            return .loopedPrimary
        }
    }

    private func helperText(for verification: CommunityVerification) -> String? {
        switch verification.status {
        case .pending:
            return "Pending review. You’ll see the result here when it’s ready."
        case .rejected:
            return "Rejected. Re-submit to verify again."
        case .expired:
            return "Re-verify to post, comment, and like in this community."
        case .active:
            return nil
        case .unknown:
            if verification.isExpired || !verification.active {
                return "Re-verify to post, comment, and like in this community."
            }
            return nil
        }
    }

    private func statusBanner(text: String, color: Color) -> some View {
        Text(text)
            .font(.loopedSubBodyRegular)
            .foregroundColor(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func joinLimitSubtitle(_ limit: SpecializationJoinLimit) -> String {
        var parts: [String] = []
        parts.append("Joined \(limit.joinedCount)/\(limit.limit)")

        if limit.cooldownActive, let cooldownEndsAt = limit.cooldownEndsAt {
            parts.append("Resets \(Self.expiryFormatter.string(from: cooldownEndsAt))")
        } else if limit.canJoin {
            parts.append("\(limit.remaining)/\(limit.limit) joins left")
        } else if limit.requiresVerificationForJoin {
            let required = limit.requiredVerificationKind?.displayName ?? "Company/School"
            parts.append("Verify your \(required.lowercased())")
        } else if limit.joinBlockedReason == .limit || limit.blockedReason == .limit {
            parts.append("Limit reached")
        }

        return parts.joined(separator: " • ")
    }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    CommunityVerificationsView()
        .environmentObject(AuthViewModel())
}
