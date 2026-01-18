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

            Text(expiryText(for: verification))
                .font(.loopedSubBodyRegular)
                .foregroundColor(verification.isExpired ? .loopedError : .loopedTextSecondary)

            if verification.isExpired || !verification.active {
                Text("Re-verify to post in this community.")
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

    private func expiryText(for verification: CommunityVerification) -> String {
        guard let expiresAt = verification.expiresAt else {
            return "Never expires"
        }
        let dateText = Self.expiryFormatter.string(from: expiresAt)
        return verification.isExpired ? "Expired \(dateText)" : "Expires \(dateText)"
    }

    private func statusText(for verification: CommunityVerification) -> String {
        if !verification.verified {
            return "Pending"
        }
        if verification.isExpired || !verification.active {
            return "Expired"
        }
        return "Active"
    }

    private func statusColor(for verification: CommunityVerification) -> Color {
        if !verification.verified {
            return .loopedSecondary
        }
        if verification.isExpired || !verification.active {
            return .loopedError
        }
        return .loopedPrimary
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
        } else if limit.blockedReason == .limit {
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
