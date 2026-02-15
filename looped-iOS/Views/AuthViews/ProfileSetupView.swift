import SwiftUI

struct ProfileSetupView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onContinue: () -> Void

    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var usernameState: UsernameAvailabilityState = .idle
    @State private var isCheckingUsername = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var usernameCheckTask: Task<Void, Never>?
    @State private var didLoadDraft = false
    @State private var toastMessage: ToastMessage?
    private let onboardingStore = OnboardingProgressStore()
    private let privacyPolicyURL = URL(string: "https://www.mylooped.app/privacy-policy")!
    private let userAgreementURL = URL(string: "https://www.mylooped.app/terms")!

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 12)

                    Text("Create your profile")
                        .font(.loopedHeading)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Choose a username and tell us a little about you.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 16) {
                        inputField(title: "Username", placeholder: "looped handle", text: $username, keyboard: .default)
                            .onChange(of: username) { _, newValue in
                                handleUsernameChange(newValue)
                            }

                        if let statusText = usernameStatusText {
                            Text(statusText)
                                .font(.loopedSmallText)
                                .foregroundColor(usernameStatusColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                        }

                        inputField(title: "First Name", placeholder: "First name", text: $firstName, keyboard: .default)
                            .onChange(of: firstName) { _, _ in
                                persistDraft()
                            }
                        inputField(title: "Last Name", placeholder: "Last name", text: $lastName, keyboard: .default)
                            .onChange(of: lastName) { _, _ in
                                persistDraft()
                            }
                        dateField(title: "Date of Birth", date: $dateOfBirth)
                            .onChange(of: dateOfBirth) { _, _ in
                                persistDraft()
                            }
                    }
                    .padding()
                    .background(Color.loopedBackground)
                    .cornerRadius(18)
                    .shadow(color: Color.loopedBlack.opacity(0.05), radius: 12, x: 0, y: 8)

                    PrimaryButton(
                        title: "Continue",
                        isEnabled: isFormValid,
                        isLoading: isSubmitting,
                        action: handleContinue
                    )

                    if isCheckingUsername {
                        ProgressView()
                            .tint(.loopedPrimary)
                    }

                    if let submitError {
                        Text(submitError)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    VStack(spacing: 4) {
                        Text("By signing up, you agree to our")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)

                        HStack(spacing: 4) {
                            Link("Privacy Policy", destination: privacyPolicyURL)
                                .font(.loopedSubBodyRegular)
                            Text("and")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                            Link("User Agreement", destination: userAgreementURL)
                                .font(.loopedSubBodyRegular)
                        }
                        .tint(.loopedSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            loadDraftIfNeeded()
        }
        .toast($toastMessage)
    }

    private var isFormValid: Bool {
        !normalizedUsername.isEmpty
            && usernameState.isAvailable
            && !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleContinue() {
        guard isFormValid else { return }
        let trimmedUsername = normalizedUsername
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        isSubmitting = true
        submitError = nil
        Task {
            defer { isSubmitting = false }
            do {
                if authViewModel.currentUser != nil || authViewModel.isProvisioned {
                    try await authViewModel.updateIdentity(
                        username: trimmedUsername,
                        firstName: trimmedFirstName,
                        lastName: trimmedLastName,
                        dateOfBirth: dateOfBirth
                    )
                } else {
                    do {
                        try await authViewModel.onboardUser(
                            username: trimmedUsername,
                            firstName: trimmedFirstName,
                            lastName: trimmedLastName,
                            dateOfBirth: dateOfBirth
                        )
                    } catch {
                        guard isAlreadyOnboardedError(error) else { throw error }
                        // Account is provisioned server-side; continue with identity update path.
                        try await authViewModel.updateIdentity(
                            username: trimmedUsername,
                            firstName: trimmedFirstName,
                            lastName: trimmedLastName,
                            dateOfBirth: dateOfBirth
                        )
                    }
                }
                await authViewModel.loadCurrentUser()
                onContinue()
            } catch {
                submitError = error.localizedDescription
            }
        }
    }

    private func handleUsernameChange(_ value: String) {
        if value != value.lowercased() {
            username = value.lowercased()
        }
        usernameCheckTask?.cancel()
        submitError = nil

        let normalized = normalizedUsername
        guard !normalized.isEmpty else {
            usernameState = .idle
            persistDraft()
            return
        }
        guard isUsernameValid(normalized) else {
            usernameState = .invalid
            persistDraft()
            return
        }

        usernameState = .checking
        persistDraft()
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await checkUsernameAvailability(for: normalized)
        }
    }

    private func checkUsernameAvailability(for value: String) async {
        guard value == normalizedUsername else { return }
        isCheckingUsername = true
        defer { isCheckingUsername = false }
        do {
            let availability = try await authViewModel.checkUsernameAvailability(value)
            guard value == normalizedUsername else { return }
            let isAvailable = availability.available || (availability.ownedByMe ?? false)
            usernameState = isAvailable ? .available(availability.username) : .unavailable
        } catch {
            guard value == normalizedUsername else { return }
            usernameState = .error
        }
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
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
        }
    }

    private func dateField(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            DatePicker("", selection: date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .foregroundColor(.loopedTextPrimary)
                .tint(.loopedPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)
        }
    }

    private func loadDraftIfNeeded() {
        guard !didLoadDraft else { return }
        didLoadDraft = true
        if let draft = onboardingStore.loadProfileDraft() {
            if username.isEmpty { username = draft.username }
            if firstName.isEmpty { firstName = draft.firstName }
            if lastName.isEmpty { lastName = draft.lastName }
            if let dob = draft.dateOfBirth {
                dateOfBirth = dob
            }
        }

        if username.isEmpty {
            username = authViewModel.currentUser?.username ?? authViewModel.currentUser?.handle ?? ""
        }
        if firstName.isEmpty {
            firstName = authViewModel.currentUser?.firstName ?? ""
        }
        if lastName.isEmpty {
            lastName = authViewModel.currentUser?.lastName ?? ""
        }
        if let dob = authViewModel.currentUser?.dateOfBirth?.yyyyMMddDate() {
            dateOfBirth = dob
        }

        if applyNameAutofillIfNeeded() {
            toastMessage = ToastMessage(text: "First and last name auto-filled.", kind: .success)
        }
        handleUsernameChange(username)
    }

    private func applyNameAutofillIfNeeded() -> Bool {
        let currentFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard currentFirst.isEmpty || currentLast.isEmpty else { return false }

        var resolvedFirst = normalizedNonEmpty(authViewModel.currentUser?.firstName)
        var resolvedLast = normalizedNonEmpty(authViewModel.currentUser?.lastName)

        if resolvedFirst == nil || resolvedLast == nil {
            let fullName = (authViewModel.currentUser?.displayName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !fullName.isEmpty {
                let parts = fullName
                    .split(whereSeparator: { $0.isWhitespace })
                    .map(String.init)
                if resolvedFirst == nil {
                    resolvedFirst = parts.first
                }
                if resolvedLast == nil, parts.count > 1 {
                    resolvedLast = parts.dropFirst().joined(separator: " ")
                }
            }
        }

        if resolvedFirst == nil || resolvedLast == nil {
            let providerName = (authViewModel.authProviderDisplayName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !providerName.isEmpty {
                let parts = providerName
                    .split(whereSeparator: { $0.isWhitespace })
                    .map(String.init)
                if resolvedFirst == nil {
                    resolvedFirst = parts.first
                }
                if resolvedLast == nil, parts.count > 1 {
                    resolvedLast = parts.dropFirst().joined(separator: " ")
                }
            }
        }

        // Apple sign-in can return name only once; ensure onboarding is never blocked.
        if authViewModel.isAppleLinked {
            if resolvedFirst == nil {
                resolvedFirst = "Apple"
            }
            if resolvedLast == nil {
                resolvedLast = "User"
            }
        }

        var didAutofill = false
        if currentFirst.isEmpty, let resolvedFirst {
            firstName = resolvedFirst
            didAutofill = true
        }
        if currentLast.isEmpty, let resolvedLast {
            lastName = resolvedLast
            didAutofill = true
        }

        if didAutofill {
            persistDraft()
        }
        return didAutofill
    }

    private func persistDraft() {
        let draft = OnboardingProfileDraft(
            username: normalizedUsername,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: dateOfBirth
        )
        onboardingStore.saveProfileDraft(draft)
    }
}

#Preview {
    NavigationStack {
        ProfileSetupView(authViewModel: AuthViewModel(), onContinue: { })
    }
}

private extension ProfileSetupView {
    enum UsernameAvailabilityState: Equatable {
        case idle
        case checking
        case available(String)
        case unavailable
        case invalid
        case error

        var isAvailable: Bool {
            if case .available = self { return true }
            return false
        }
    }

    var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var usernameStatusText: String? {
        switch usernameState {
        case .idle:
            return nil
        case .checking:
            return "Checking availability..."
        case .available(let normalized):
            return "Available: @\(normalized)"
        case .unavailable:
            return "That username is taken."
        case .invalid:
            return "Use 3-30 lowercase letters, numbers, or underscores."
        case .error:
            return "Couldn't check username right now."
        }
    }

    var usernameStatusColor: Color {
        switch usernameState {
        case .available:
            return .loopedSuccess
        case .checking:
            return .loopedTextSecondary
        default:
            return .loopedError
        }
    }

    func isUsernameValid(_ value: String) -> Bool {
        let pattern = "^[a-z0-9_]{3,30}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    func normalizedNonEmpty(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func isAlreadyOnboardedError(_ error: Error) -> Bool {
        guard case let APIError.apiError(_, apiError, _) = error else { return false }
        let normalized = apiError.lowercased()
        return normalized == "already_onboarded"
            || normalized == "user_already_onboarded"
            || normalized == "already_provisioned"
    }
}
