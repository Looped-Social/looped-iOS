import SwiftUI

struct ProfileSetupView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onBack: () -> Void
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
    private let onboardingStore = OnboardingProgressStore()

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.loopedCustom(.medium, size: 18))
                            .foregroundColor(.loopedTextPrimary)
                            .padding(10)
                            .background(Color.loopedMutedBackground)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                ScrollView {
                    VStack(spacing: 20) {
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

                        Button(action: handleContinue) {
                            Text("Continue")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(isFormValid ? Color.loopedPrimary : Color.loopedTextSecondary.opacity(0.3))
                                .cornerRadius(14)
                        }
                        .disabled(!isFormValid || isSubmitting)

                        if isCheckingUsername || isSubmitting {
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
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            loadDraftIfNeeded()
        }
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
                try await authViewModel.onboardUser(
                    username: trimmedUsername,
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    dateOfBirth: dateOfBirth
                )
                onboardingStore.clearProfileDraft()
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
            usernameState = availability.available ? .available(availability.username) : .unavailable
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
        guard let draft = onboardingStore.loadProfileDraft() else { return }
        if username.isEmpty { username = draft.username }
        if firstName.isEmpty { firstName = draft.firstName }
        if lastName.isEmpty { lastName = draft.lastName }
        if let dob = draft.dateOfBirth {
            dateOfBirth = dob
        }
        handleUsernameChange(username)
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
    ProfileSetupView(authViewModel: AuthViewModel(), onBack: { }, onContinue: { })
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
}
