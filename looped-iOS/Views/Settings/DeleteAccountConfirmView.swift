import SwiftUI

struct DeleteAccountConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("showAccountDeletedAlert") private var showAccountDeletedAlert = false

    private let userService: UserServiceProtocol = UserService()
    private let anonService = AnonService.shared

    @State private var confirmationText = ""
    @State private var isDeleting = false
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

                    Text("Type the phrase below to confirm deletion.")
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

                    Text("This will delete both your regular account and your anonymous profile.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)

                    PrimaryButton(
                        title: "Confirm delete",
                        isEnabled: isMatch,
                        isLoading: isDeleting
                    ) {
                        deleteAccount()
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
        .alert("Delete Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var expectedPhrase: String {
        let rawUsername = authViewModel.currentUser?.username ?? authViewModel.currentUser?.handle ?? "your username"
        let resolved = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return "delete my account for \(resolved)"
    }

    private var isMatch: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == expectedPhrase
    }

    private func deleteAccount() {
        guard isMatch, !isDeleting else { return }
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await anonService.revokeIfPresent()
                try await userService.deleteAccount(mode: .hard)
                showAccountDeletedAlert = true
                authViewModel.signOut()
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
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

            Text("Confirm Delete")
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
}

#Preview {
    DeleteAccountConfirmView()
        .environmentObject(AuthViewModel())
}
