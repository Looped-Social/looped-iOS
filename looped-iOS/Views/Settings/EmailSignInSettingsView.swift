import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct EmailSignInSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    @State private var showReauthSheet = false
    @State private var reauthPassword = ""
    @State private var reauthErrorMessage: String?
    @State private var pendingEmailUpdate: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                infoText

                VStack(spacing: 14) {
                    inputField(
                        title: "Email",
                        placeholder: "you@example.com",
                        text: $email,
                        keyboard: .emailAddress
                    )

                    if !authViewModel.isEmailPasswordLinked {
                        passwordField(
                            title: "Password",
                            placeholder: "Create a password",
                            text: $password
                        )
                    }
                }
                .padding(16)
                .background(Color.loopedWhite)
                .cornerRadius(16)
                .shadow(color: Color.loopedBlack.opacity(0.05), radius: 10, x: 0, y: 8)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedError)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                }

                Button(action: handleSave) {
                    Text(primaryButtonTitle)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(primaryButtonEnabled ? Color.loopedPrimary : Color.loopedTextSecondary.opacity(0.3))
                        .clipShape(Capsule())
                }
                .disabled(!primaryButtonEnabled || isSaving)
                .padding(.top, 6)

                if isSaving {
                    ProgressView()
                        .tint(.loopedPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            guard !didLoad else { return }
            email = authViewModel.emailForEmailPasswordLogin
            didLoad = true
        }
        .sheet(isPresented: $showReauthSheet) {
            reauthSheet
        }
    }
}

private extension EmailSignInSettingsView {
    enum EmailSignInSettingsError: LocalizedError {
        case missingUser

        var errorDescription: String? {
            switch self {
            case .missingUser:
                return "Please sign out and sign back in, then try again."
            }
        }
    }

    var infoText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(authViewModel.isEmailPasswordLinked ? "Update your email" : "Add an email login")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Text(authViewModel.isEmailPasswordLinked
                 ? "This is the email you use to log in with a password."
                 : "If you signed up with Google or Apple, add an email and password to enable email login.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
    }

    var primaryButtonTitle: String {
        authViewModel.isEmailPasswordLinked ? "Update Email" : "Add Email Login"
    }

    var primaryButtonEnabled: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValid(email: trimmedEmail) else { return false }
        if authViewModel.isEmailPasswordLinked {
            return true
        }
        return password.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
    }

    var reauthSheet: some View {
        VStack(spacing: 20) {
            Text("Confirm Password")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            SecureField("Password", text: $reauthPassword)
                .font(.loopedBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)

            if let reauthErrorMessage {
                Text(reauthErrorMessage)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedError)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    showReauthSheet = false
                    reauthPassword = ""
                    reauthErrorMessage = nil
                }
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.loopedMutedBackground)
                .clipShape(Capsule())

                Button("Continue") {
                    Task { await confirmReauthAndRetry() }
                }
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.loopedPrimary)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .presentationDetents([.medium])
    }

    func handleSave() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValid(email: trimmedEmail) else {
            errorMessage = "Enter a valid email address."
            return
        }

        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if !authViewModel.isEmailPasswordLinked, trimmedPassword.count < 8 {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }
            do {
                if authViewModel.isEmailPasswordLinked {
                    try await updateEmail(to: trimmedEmail)
                } else {
                    try await linkEmailLogin(email: trimmedEmail, password: trimmedPassword)
                }

                await MainActor.run {
                    authViewModel.refreshLinkedProviders()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    if isRequiresRecentLogin(error) {
                        pendingEmailUpdate = trimmedEmail
                        showReauthSheet = authViewModel.isEmailPasswordLinked
                        if !authViewModel.isEmailPasswordLinked {
                            errorMessage = "Please sign out and sign back in to add an email login."
                        }
                        return
                    }
                    errorMessage = friendlyMessage(for: error)
                }
            }
        }
    }

    func confirmReauthAndRetry() async {
        let trimmedPassword = reauthPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassword.isEmpty else {
            reauthErrorMessage = "Enter your password."
            return
        }

        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser, let currentEmail = user.email else {
            reauthErrorMessage = "Missing account email."
            return
        }

        do {
            let credential = EmailAuthProvider.credential(withEmail: currentEmail, password: trimmedPassword)
            _ = try await user.reauthenticate(with: credential)

            let pendingEmail = pendingEmailUpdate
            pendingEmailUpdate = nil

            showReauthSheet = false
            reauthPassword = ""
            reauthErrorMessage = nil

            if let pendingEmail {
                isSaving = true
                errorMessage = nil
                do {
                    try await updateEmail(to: pendingEmail)
                    await MainActor.run {
                        authViewModel.refreshLinkedProviders()
                        dismiss()
                    }
                } catch {
                    errorMessage = friendlyMessage(for: error)
                }
                isSaving = false
            }
        } catch {
            reauthErrorMessage = friendlyMessage(for: error)
        }
        #else
        reauthErrorMessage = "Email updates are unavailable."
        #endif
    }

    func updateEmail(to value: String) async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { throw EmailSignInSettingsError.missingUser }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.updateEmail(to: value) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        #endif
    }

    func linkEmailLogin(email: String, password: String) async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { throw EmailSignInSettingsError.missingUser }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.link(with: credential) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        #endif
    }

    func isValid(email value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count <= 320
    }

    func isRequiresRecentLogin(_ error: Error) -> Bool {
        #if canImport(FirebaseAuth)
        let nsError = error as NSError
        if let code = AuthErrorCode(rawValue: nsError.code) {
            return code == .requiresRecentLogin
        }
        #endif
        return false
    }

    func friendlyMessage(for error: Error) -> String {
        #if canImport(FirebaseAuth)
        let nsError = error as NSError
        if let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidEmail:
                return "Enter a valid email address."
            case .emailAlreadyInUse:
                return "That email is already in use."
            case .weakPassword:
                return "Choose a stronger password."
            case .wrongPassword:
                return "Incorrect password."
            default:
                break
            }
        }
        #endif
        return error.localizedDescription
    }

    func inputField(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            TextField(placeholder, text: text)
                .font(.loopedBody)
                .foregroundColor(.loopedTextPrimary)
                .tint(.loopedPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
        }
    }

    func passwordField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            HStack(spacing: 12) {
                Group {
                    if isPasswordVisible {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .foregroundColor(.loopedTextPrimary)
                .tint(.loopedPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(isPasswordVisible ? "Hide" : "Show") {
                    isPasswordVisible.toggle()
                }
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedSecondary)
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }
            .font(.loopedBody)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.loopedMutedBackground.opacity(0.6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    NavigationStack {
        EmailSignInSettingsView()
            .environmentObject(AuthViewModel())
    }
}
