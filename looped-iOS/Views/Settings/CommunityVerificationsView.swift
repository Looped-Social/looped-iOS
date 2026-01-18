import SwiftUI

struct CommunityVerificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CommunityVerificationsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel.joinLimits.isEmpty {
                        joinLimitsCard
                    }

                    if viewModel.isLoading && viewModel.items.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if viewModel.items.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.items) { verification in
                            verificationRow(verification)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        statusBanner(text: errorMessage, color: .loopedError)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await viewModel.load() }
    }

    private var joinLimitsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Specializations")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            ForEach(viewModel.joinLimits, id: \.specializationType) { limit in
                VStack(alignment: .leading, spacing: 4) {
                    Text(limit.pluralLabel)
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(joinLimitSubtitle(limit))
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }
            }
        }
        .padding(14)
        .background(Color.loopedMutedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack {
            LoopedBackButton(action: { dismiss() })

            Image("logo-banner")
                .resizable()
                .scaledToFit()
                .frame(height: 36)

            Spacer()

            Text("Verifications")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
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
        .padding(14)
        .background(Color.loopedMutedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
}
