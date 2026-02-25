import SwiftUI

struct AccountActionConfirmView: View {
    let action: AccountActionKind
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("showAccountDeletedAlert") private var showAccountDeletedAlert = false
    @AppStorage("showAccountDeletionPendingAlert") private var showAccountDeletionPendingAlert = false
    @AppStorage("showAccountDeactivatedAlert") private var showAccountDeactivatedAlert = false

    private let userService: UserServiceProtocol = UserService()
    private let anonService = AnonService.shared

    @State private var confirmationText = ""
    @State private var isProcessing = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var processingStatus: ProcessingStatus = .starting
    @State private var processingStatusTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Final confirmation")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)

                Text(promptText)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextSecondary)

                Text(expectedPhrase)
                    .font(.loopedBodyStrong)
                    .foregroundColor(.loopedTextPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.loopedTextSecondary.opacity(0.08))
                    .cornerRadius(10)

                TextField("Type phrase here", text: $confirmationText)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color.loopedTextSecondary.opacity(0.1))
                    .cornerRadius(8)

                Text(detailText)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)

                PrimaryButton(
                    title: buttonTitle,
                    isEnabled: isMatch,
                    isLoading: isProcessing
                ) {
                    performAction()
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle(headerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isProcessing)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .loadingOverlay(
            isPresented: isProcessing,
            title: processingTitle,
            subtitle: processingSubtitle
        )
        .alert(alertTitle, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            processingStatusTask?.cancel()
            processingStatusTask = nil
        }
    }

    private var expectedPhrase: String {
        let rawUsername = authViewModel.currentUser?.username ?? authViewModel.currentUser?.handle ?? "your username"
        let resolved = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(expectedPhrasePrefix) \(resolved)"
    }

    private var expectedPhrasePrefix: String {
        switch action {
        case .delete:
            return "delete my account for"
        case .deactivate:
            return "deactivate my account for"
        }
    }

    private var isMatch: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == expectedPhrase
    }

    private func performAction() {
        guard isMatch, !isProcessing else { return }
        isProcessing = true
        startProcessingStatusUpdates()
        Task {
            defer {
                isProcessing = false
                processingStatusTask?.cancel()
                processingStatusTask = nil
                processingStatus = .starting
            }
            do {
                if action == .delete {
                    try await anonService.revokeIfPresent()
                }
                let result = try await userService.deleteAccount(mode: deleteMode)
                switch action {
                case .delete:
                    if result.deletePending {
                        showAccountDeletionPendingAlert = true
                    } else {
                        showAccountDeletedAlert = true
                    }
                case .deactivate:
                    showAccountDeactivatedAlert = true
                }
                authViewModel.signOut()
            } catch {
                errorMessage = userFacingErrorMessage(for: error)
                showErrorAlert = true
            }
        }
    }

    private func startProcessingStatusUpdates() {
        processingStatusTask?.cancel()
        processingStatus = .starting
        processingStatusTask = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard isProcessing else { return }
                processingStatus = .takingLongerThanExpected
            }
        }
    }

    private var deleteMode: DeleteAccountMode {
        switch action {
        case .delete:
            return .hard
        case .deactivate:
            return .soft
        }
    }

    private var headerTitle: String {
        switch action {
        case .delete:
            return "Confirm Delete"
        case .deactivate:
            return "Confirm Deactivation"
        }
    }

    private var promptText: String {
        switch action {
        case .delete:
            return "Type the phrase below to confirm deletion."
        case .deactivate:
            return "Type the phrase below to confirm deactivation."
        }
    }

    private var detailText: String {
        switch action {
        case .delete:
            return "This will delete both your regular account and your anonymous profile."
        case .deactivate:
            return "Deactivation is a reversible pause. Your profile is hidden, you will not show in search or feed, and you will not receive notifications. Log back in to reactivate. If you do not reactivate within 90 days, your account will be deleted."
        }
    }

    private var buttonTitle: String {
        switch action {
        case .delete:
            return "Confirm delete"
        case .deactivate:
            return "Confirm deactivation"
        }
    }

    private var alertTitle: String {
        switch action {
        case .delete:
            return "Delete Failed"
        case .deactivate:
            return "Deactivation Failed"
        }
    }

    private var processingTitle: String {
        switch action {
        case .delete:
            return "Deleting Account..."
        case .deactivate:
            return "Deactivating Account..."
        }
    }

    private var processingSubtitle: String {
        switch processingStatus {
        case .starting:
            return "Please keep this screen open until the request finishes."
        case .takingLongerThanExpected:
            return "This is taking longer than expected. We are still processing your request."
        }
    }

    private func userFacingErrorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            if case APIError.networkError(let underlyingError) = apiError,
               let urlError = underlyingError as? URLError,
               urlError.code == .timedOut {
                return "The request timed out. This can happen during heavy load. Please try again in a minute."
            }
            if case APIError.networkError = apiError {
                return "Network issue while processing your request. Please check your connection and try again."
            }
        }

        return error.localizedDescription
    }
}

private extension AccountActionConfirmView {
    enum ProcessingStatus {
        case starting
        case takingLongerThanExpected
    }
}

struct DeleteAccountConfirmView: View {
    var body: some View {
        AccountActionConfirmView(action: .delete)
    }
}

struct DeactivateAccountConfirmView: View {
    var body: some View {
        AccountActionConfirmView(action: .deactivate)
    }
}

#Preview {
    AccountActionConfirmView(action: .delete)
        .environmentObject(AuthViewModel())
}
