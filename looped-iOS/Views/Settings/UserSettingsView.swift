import SwiftUI
import UIKit

struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    private let userService: UserServiceProtocol = UserService()
    private let verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()

    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var bio: String = ""
    @State private var emailNotifications = true
    @State private var pushNotifications = true
    @State private var hasLoadedUser = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var usernameState: UsernameAvailabilityState = .idle
    @State private var isCheckingUsername = false
    @State private var usernameCheckTask: Task<Void, Never>?
    @State private var verifiedCommunities: [CommunityVerification] = []
    @State private var displayCommunityId: Int?
    @State private var initialDisplayCommunityId: Int?
    @State private var isLoadingDisplayCommunities = false
    @State private var displayCommunityError: String?
    @State private var toastMessage: ToastMessage?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text("Edit Profile")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                // Invisible button for symmetry
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 12)

            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Picture Section
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.loopedTextSecondary)

                        Button("Change Profile Picture") {
                            // TODO: Implement photo picker
                        }
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedSecondary)
                    }
                    .padding(.top, 20)

                    // Username Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        TextField("Username", text: $username)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .padding(12)
                            .background(Color.loopedTextSecondary.opacity(0.1))
                            .cornerRadius(8)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled()
                            .onChange(of: username) { _, newValue in
                                handleUsernameChange(newValue)
                            }

                        if let statusText = usernameStatusText {
                            Text(statusText)
                                .font(.loopedSmallText)
                                .foregroundColor(usernameStatusColor)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Display Community Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Community")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        Text("Choose a verified community to show on your profile and posts.")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)

                        if isLoadingDisplayCommunities {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Loading verified communities...")
                                    .font(.loopedSubBodyRegular)
                                    .foregroundColor(.loopedTextSecondary)
                            }
                            .padding(.vertical, 8)
                        } else if verifiedCommunities.isEmpty {
                            DisplayCommunityRow(
                                displayCommunity: selectedDisplayCommunity,
                                fallbackText: "Verify a community to add it here",
                                font: .loopedBody,
                                textColor: selectedDisplayCommunity == nil ? .loopedTextSecondary : .loopedTextPrimary,
                                iconSize: 18
                            )
                            .padding(12)
                            .background(Color.loopedTextSecondary.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            Picker(
                                selection: $displayCommunityId,
                                label: DisplayCommunityRow(
                                    displayCommunity: selectedDisplayCommunity,
                                    fallbackText: "Select a primary community",
                                    font: .loopedBody,
                                    textColor: selectedDisplayCommunity == nil ? .loopedTextSecondary : .loopedTextPrimary,
                                    iconSize: 18,
                                    showsDisclosure: true
                                )
                                .padding(12)
                                .background(Color.loopedTextSecondary.opacity(0.1))
                                .cornerRadius(8)
                            ) {
                                Text("None").tag(Int?.none)
                                ForEach(verifiedCommunities) { verification in
                                    let option = DisplayCommunity(verification: verification)
                                    Text(option.displayText)
                                        .tag(Optional(verification.communityId))
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(isSaving)
                        }

                        if let displayCommunityError {
                            Text(displayCommunityError)
                                .font(.loopedSmallText)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 20)

                    // First Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First Name")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        TextField("First Name", text: $firstName)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .padding(12)
                            .background(Color.loopedTextSecondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)

                    // Last Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Name")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        TextField("Last Name", text: $lastName)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .padding(12)
                            .background(Color.loopedTextSecondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)

                    // Date of Birth Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of Birth")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)

                    // Bio Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $bio)
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextPrimary)
                                .scrollContentBackground(.hidden)
                                .padding(8)

                            if bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Tell us a bit about you")
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                            }
                        }
                        .frame(minHeight: 110)
                        .background(Color.loopedTextSecondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)

                    // Save Button
                    Button(action: saveProfile) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isSaving ? "Saving..." : "Save Changes")
                                .font(.loopedBodyStrong)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(saveButtonColor)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving || !isFormValid)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    if let saveError = saveError {
                        Text(saveError)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 100)
            }
            }

        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .toast($toastMessage)
        .onAppear {
            hydrateFromUser()
            Task { await loadVerifiedCommunities() }
        }
        .onChange(of: authViewModel.currentUser?.id) { _ in
            hasLoadedUser = false
            hydrateFromUser()
            Task { await loadVerifiedCommunities() }
        }
        .navigationBarHidden(true)
    }
}

struct UserSettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            Spacer()

            Text(value)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private extension UserSettingsView {
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

    var currentUser: User? { authViewModel.currentUser }

    var selectedDisplayCommunity: DisplayCommunity? {
        guard let id = displayCommunityId else { return nil }
        if let verification = verifiedCommunities.first(where: { $0.communityId == id }) {
            return DisplayCommunity(verification: verification)
        }
        if let current = currentUser?.displayCommunity, current.id == id {
            return current
        }
        return nil
    }

    func hydrateFromUser() {
        guard let user = currentUser, !hasLoadedUser else { return }
        username = user.username ?? user.handle
        usernameState = .idle
        usernameCheckTask?.cancel()
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        if let dob = user.dateOfBirth?.yyyyMMddDate() {
            dateOfBirth = dob
        }
        bio = user.bio ?? ""
        displayCommunityId = user.displayCommunity?.id
        initialDisplayCommunityId = user.displayCommunity?.id
        hasLoadedUser = true
    }

    func loadVerifiedCommunities() async {
        guard !isLoadingDisplayCommunities else { return }
        isLoadingDisplayCommunities = true
        displayCommunityError = nil
        defer { isLoadingDisplayCommunities = false }
        do {
            let items = try await verificationService.fetchCommunityVerifications()
            verifiedCommunities = items.filter { $0.isActive }
        } catch {
            displayCommunityError = error.localizedDescription
            verifiedCommunities = []
        }
    }

    func saveProfile() {
        guard !isSaving else { return }
        guard isFormValid else { return }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        saveError = nil
        displayCommunityError = nil
        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                let trimmedUsername = normalizedUsername
                let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayName = "\(trimmedFirstName) \(trimmedLastName)"

                _ = try await userService.updateIdentity(
                    username: trimmedUsername,
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName,
                    dateOfBirth: dateOfBirth.yyyyMMddString()
                )
                _ = try await userService.updateProfile(
                    displayName: displayName,
                    bio: bio.isEmpty ? nil : bio,
                    isAnonymous: false,
                    showFollowerCount: nil
                )
                if displayCommunityId != initialDisplayCommunityId {
                    _ = try await userService.updateDisplayCommunity(communityId: displayCommunityId)
                    initialDisplayCommunityId = displayCommunityId
                }
                await authViewModel.loadCurrentUser()
                presentToast(message: "Changes saved")
            } catch {
                saveError = mapSaveError(error)
                presentToast(message: "Changes not saved")
            }
        }
    }

    var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isFormValid: Bool {
        isUsernameReady
            && !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var saveButtonColor: Color {
        isSaving || !isFormValid ? Color.loopedPrimary.opacity(0.7) : Color.loopedPrimary
    }

    func handleUsernameChange(_ value: String) {
        if value != value.lowercased() {
            username = value.lowercased()
        }
        usernameCheckTask?.cancel()
        saveError = nil

        let normalized = normalizedUsername
        guard !normalized.isEmpty else {
            usernameState = .idle
            return
        }
        guard isUsernameValid(normalized) else {
            usernameState = .invalid
            return
        }
        if let currentUsername = currentUsernameNormalized, normalized == currentUsername {
            usernameState = .idle
            return
        }

        usernameState = .checking
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await checkUsernameAvailability(for: normalized)
        }
    }

    func checkUsernameAvailability(for value: String) async {
        guard value == normalizedUsername else { return }
        isCheckingUsername = true
        defer { isCheckingUsername = false }
        do {
            let availability = try await userService.checkUsernameAvailability(value)
            guard value == normalizedUsername else { return }
            usernameState = availability.available ? .available(availability.username) : .unavailable
        } catch {
            guard value == normalizedUsername else { return }
            usernameState = .error
        }
    }

    var isUsernameReady: Bool {
        let normalized = normalizedUsername
        guard !normalized.isEmpty, isUsernameValid(normalized) else { return false }
        if let currentUsername = currentUsernameNormalized, normalized == currentUsername {
            return true
        }
        return usernameState.isAvailable
    }

    var currentUsernameNormalized: String? {
        let raw = currentUser?.username ?? currentUser?.handle ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
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
            return .green
        case .checking:
            return .loopedTextSecondary
        default:
            return .red
        }
    }

    func isUsernameValid(_ value: String) -> Bool {
        let pattern = "^[a-z0-9_]{3,30}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    func mapSaveError(_ error: Error) -> String {
        if case let APIError.apiError(_, apiError, message) = error {
            switch apiError {
            case "user_not_provisioned":
                return "Your account isn't fully onboarded yet."
            case "invalid_username":
                usernameState = .invalid
                return "Use 3-30 lowercase letters, numbers, or underscores."
            case "username_taken":
                usernameState = .unavailable
                return "That username is already taken."
            case "community_not_verified":
                return "You must be verified in that community to display it."
            case "community_not_found":
                return "That community could not be found."
            default:
                if let message, !message.isEmpty {
                    return message
                }
                return apiError
            }
        }
        return error.localizedDescription
    }

    func presentToast(message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = ToastMessage(text: message)
        }
    }
}

#Preview {
    UserSettingsView()
        .environmentObject(AuthViewModel())
}
