import SwiftUI

struct AccountActionConfirmView: View {
    let action: AccountActionKind
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("showAccountDeletedAlert") private var showAccountDeletedAlert = false
    @AppStorage("showAccountDeactivatedAlert") private var showAccountDeactivatedAlert = false

    private let userService: UserServiceProtocol = UserService()
    private let anonService = AnonService.shared

    @State private var confirmationText = ""
    @State private var isProcessing = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            header

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
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert(alertTitle, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
        Task {
            defer { isProcessing = false }
            do {
                if action == .delete {
                    try await anonService.revokeIfPresent()
                }
                try await userService.deleteAccount(mode: deleteMode)
                switch action {
                case .delete:
                    showAccountDeletedAlert = true
                case .deactivate:
                    showAccountDeactivatedAlert = true
                }
                authViewModel.signOut()
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
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

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            Text(headerTitle)
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Image(systemName: "chevron.left")
                .font(.system(size: 24, weight: .medium))
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
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
