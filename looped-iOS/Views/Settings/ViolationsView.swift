import SwiftUI

struct ViolationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ViolationsViewModel()
    @StateObject private var appealsViewModel = AppealsViewModel()
    @State private var activeAppeal: Violation?
    @State private var alertMessage: String?
    @State private var selectedTab: ViolationsTab = .violations

    private let moderationService: ModerationServiceProtocol = ModerationService()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    tabPicker

                    if selectedTab == .violations {
                        violationsContent
                    } else {
                        appealsContent
                    }

                    if viewModel.isLoadingMore && selectedTab == .violations {
                        ProgressView()
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadViolations()
            await appealsViewModel.loadAppeals()
        }
        .sheet(item: $activeAppeal) { violation in
            ModerationReasonSheet(
                title: appealTitle(for: violation),
                subtitle: "Tell us why this should be reviewed.",
                placeholder: "Share details or context...",
                submitTitle: "Submit Appeal",
                onSubmit: { reason in
                    let targetId = violation.targetType == .postRemoval ? violation.targetId : nil
                    _ = try await moderationService.createAppeal(
                        targetType: violation.appealTargetType,
                        targetId: targetId,
                        reason: reason
                    )
                },
                onSuccess: {
                    alertMessage = "Appeal submitted. We'll review it soon."
                }
            )
        }
        .alert(
            "Submitted",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            LoopedBackButton(action: { dismiss() })

            Spacer()

            Text("Appeals & Violations")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            LoopedBackButton(action: {})
                .opacity(0)
                .disabled(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }

    private var tabPicker: some View {
        Picker("Appeals or Violations", selection: $selectedTab) {
            ForEach(ViolationsTab.allCases, id: \.self) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var violationsContent: some View {
        if viewModel.isLoading && viewModel.violations.isEmpty {
            ProgressView()
                .padding(.top, 24)
        }

        if let errorMessage = viewModel.errorMessage, viewModel.violations.isEmpty {
            Text(errorMessage)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedError)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }

        if viewModel.violations.isEmpty && viewModel.errorMessage == nil && !viewModel.isLoading {
            emptyState
        } else {
            ForEach(viewModel.violations) { violation in
                violationCard(for: violation)
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(current: violation) }
                    }
            }
        }
    }

    @ViewBuilder
    private var appealsContent: some View {
        if appealsViewModel.isLoading && appealsViewModel.appeals.isEmpty {
            ProgressView()
                .padding(.top, 24)
        }

        if let errorMessage = appealsViewModel.errorMessage, appealsViewModel.appeals.isEmpty {
            Text(errorMessage)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedError)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }

        if appealsViewModel.appeals.isEmpty && appealsViewModel.errorMessage == nil && !appealsViewModel.isLoading {
            emptyAppealsState
        } else {
            ForEach(appealsViewModel.appeals) { appeal in
                appealCard(for: appeal)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.loopedCustom(.semibold, size: 32))
                .foregroundColor(.loopedSecondary)
            Text("No violations found")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
            Text("If a post is removed or your account is restricted, it will appear here.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }

    private var emptyAppealsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.loopedCustom(.semibold, size: 32))
                .foregroundColor(.loopedSecondary)
            Text("No appeals yet")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
            Text("If you submit an appeal, it will appear here.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }

    private func violationCard(for violation: Violation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(violation.title)
                        .font(.loopedBodyStrong)
                        .foregroundColor(.loopedTextPrimary)
                    Text(violation.subtitle)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text(violation.statusText)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.loopedSecondary.opacity(0.12))
                    .cornerRadius(8)
            }

            if !violation.reason.isEmpty {
                Text(violation.reason)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextPrimary)
            }

            HStack {
                Text(violation.createdAt, style: .date)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)

                Spacer()

                if violation.canAppeal {
                    Button("Appeal") {
                        activeAppeal = violation
                    }
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.loopedPrimary.opacity(0.12))
                    .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(Color.loopedTextSecondary.opacity(0.05))
        .cornerRadius(14)
    }

    private func appealCard(for appeal: Appeal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appeal.title)
                        .font(.loopedBodyStrong)
                        .foregroundColor(.loopedTextPrimary)
                    Text(appeal.subtitle)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text(appeal.statusText)
                    .font(.loopedSmallText)
                    .foregroundColor(statusColor(for: appeal.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(for: appeal.status).opacity(0.12))
                    .cornerRadius(8)
            }

            Text(appeal.reason)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextPrimary)

            if let reviewedReason = appeal.reviewedReason, !reviewedReason.isEmpty {
                Text("Review: \(reviewedReason)")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            HStack {
                Text(appeal.createdAt, style: .date)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                Spacer()
                if let reviewedAt = appeal.reviewedAt {
                    Text("Reviewed \(reviewedAt, style: .date)")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.loopedTextSecondary.opacity(0.05))
        .cornerRadius(14)
    }

    private func appealTitle(for violation: Violation) -> String {
        switch violation.targetType {
        case .postRemoval:
            return "Appeal Post Removal"
        case .userBan:
            return "Appeal Account Ban"
        case .unknown:
            return "Submit Appeal"
        }
    }

    private func statusColor(for status: AppealStatus) -> Color {
        switch status {
        case .open:
            return .loopedSecondary
        case .approved:
            return .loopedSuccess
        case .rejected:
            return .loopedError
        case .unknown:
            return .loopedTextSecondary
        }
    }
}

private enum ViolationsTab: String, CaseIterable {
    case violations
    case appeals

    var title: String {
        switch self {
        case .violations:
            return "Violations"
        case .appeals:
            return "Appeals"
        }
    }
}

#Preview {
    ViolationsView()
}
