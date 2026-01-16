import SwiftUI
import UIKit
import PhotosUI

struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("anonymousMode") private var isAnonymousMode = false

    private let userService: UserServiceProtocol = UserService()
    private let verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()
    private let mediaService: MediaServiceProtocol = MediaService()
    private let anonService = AnonService.shared

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
    @State private var displaySpecialization: DisplayCommunity?
    @State private var initialDisplaySpecializationId: Int?
    @State private var displaySpecializationError: String?
    @State private var isShowingSpecializationPicker = false
    @State private var anonDisplayCommunities: [DisplayCommunity] = []
    @State private var anonDisplayCommunityId: Int?
    @State private var initialAnonDisplayCommunityId: Int?
    @State private var isLoadingAnonDisplayCommunities = false
    @State private var anonDisplayCommunityError: String?
    @State private var anonHandle: String?
    @State private var anonDisplaySpecialization: DisplayCommunity?
    @State private var initialAnonDisplaySpecializationId: Int?
    @State private var anonDisplaySpecializationError: String?
    @State private var isShowingAnonSpecializationPicker = false
    @State private var toastMessage: ToastMessage?
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var profilePhotoPreview: UIImage?
    @State private var profilePhotoPayload: ImageUploadPayload?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.loopedCustom(.medium, size: 24))
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text("Edit Profile")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                // Invisible button for symmetry
                Image(systemName: "chevron.left")
                    .font(.loopedCustom(.medium, size: 24))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 12)

            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    if isAnonymousMode {
                        VStack(spacing: 12) {
                            ProfileAvatarView(imageURL: nil, size: 96, iconScale: 0.4)

                            Text("Anonymous profiles don’t have a profile photo")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedSecondary)
                        }
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.loopedBodyStrong)
                                .foregroundColor(.loopedTextPrimary)

                            HStack {
                                Text(anonFormattedHandle)
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedTextSecondary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.loopedTextSecondary.opacity(0.1))
                            .cornerRadius(8)

                            Text("Anonymous usernames can’t be changed.")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Community")
                                .font(.loopedBodyStrong)
                                .foregroundColor(.loopedTextPrimary)

                            Text("Choose a community to show on your anonymous profile and posts.")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)

                            if isLoadingAnonDisplayCommunities {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Loading anonymous communities...")
                                        .font(.loopedSubBodyRegular)
                                        .foregroundColor(.loopedTextSecondary)
                                }
                                .padding(.vertical, 8)
                            } else if anonDisplayCommunities.isEmpty {
                                DisplayCommunityRow(
                                    displayCommunity: selectedAnonDisplayCommunity,
                                    fallbackText: "Enable anonymous mode in a community first",
                                    font: .loopedBody,
                                    textColor: selectedAnonDisplayCommunity == nil ? .loopedTextSecondary : .loopedTextPrimary,
                                    iconSize: 18
                                )
                                .padding(12)
                                .background(Color.loopedTextSecondary.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                Picker(
                                    selection: $anonDisplayCommunityId,
                                    label: DisplayCommunityRow(
                                        displayCommunity: selectedAnonDisplayCommunity,
                                        fallbackText: "Select a community",
                                        font: .loopedBody,
                                        textColor: selectedAnonDisplayCommunity == nil ? .loopedTextSecondary : .loopedTextPrimary,
                                        iconSize: 18,
                                        showsDisclosure: true
                                    )
                                    .padding(12)
                                    .background(Color.loopedTextSecondary.opacity(0.1))
                                    .cornerRadius(8)
                                ) {
                                    Text("None").tag(Int?.none)
                                    ForEach(anonDisplayCommunities, id: \.id) { community in
                                        Text(community.displayText)
                                            .tag(Optional(community.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .disabled(isSaving)
                            }

                            if let anonDisplayCommunityError {
                                Text(anonDisplayCommunityError)
                                    .font(.loopedSmallText)
                                    .foregroundColor(.loopedError)
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Specialization")
                                .font(.loopedBodyStrong)
                                .foregroundColor(.loopedTextPrimary)

                            Text("Choose a major or department to show on your anonymous profile.")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)

                            Button(action: { isShowingAnonSpecializationPicker = true }) {
                                DisplaySpecializationRow(
                                    specialization: anonDisplaySpecialization,
                                    displayCommunity: selectedAnonDisplayCommunity,
                                    fallbackText: "Select a major or department",
                                    font: .loopedBody,
                                    textColor: anonDisplaySpecialization == nil ? .loopedTextSecondary : .loopedTextPrimary,
                                    iconSize: 18,
                                    showsDisclosure: true,
                                    showsCommunityFallback: false
                                )
                                .padding(12)
                                .background(Color.loopedTextSecondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isSaving)

                            if let anonDisplaySpecializationError {
                                Text(anonDisplaySpecializationError)
                                    .font(.loopedSmallText)
                                    .foregroundColor(.loopedError)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    Group {
                                        if let profilePhotoPreview {
                                            Image(uiImage: profilePhotoPreview)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 96, height: 96)
                                                .clipShape(Circle())
                                        } else {
                                            ProfileAvatarView(imageURL: authViewModel.currentUser?.profileImageURL, size: 96, iconScale: 0.4)
                                        }
                                    }

                                    Circle()
                                        .fill(Color.loopedPrimary)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.loopedCustom(size: 14))
                                                .foregroundColor(.loopedWhite)
                                        )
                                }
                            }
                            .onChange(of: selectedProfilePhoto) { _, newValue in
                                Task { await handleProfilePhotoSelection(newValue) }
                            }

                            Text("Tap to change profile photo")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedSecondary)
                        }
                        .padding(.top, 20)

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
                                    .foregroundColor(.loopedError)
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Specialization")
                                .font(.loopedBodyStrong)
                                .foregroundColor(.loopedTextPrimary)

                            Text("Choose a major or department to show on your profile.")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)

                            Button(action: { isShowingSpecializationPicker = true }) {
                                DisplaySpecializationRow(
                                    specialization: displaySpecialization,
                                    displayCommunity: selectedDisplayCommunity,
                                    fallbackText: "Select a major or department",
                                    font: .loopedBody,
                                    textColor: displaySpecialization == nil ? .loopedTextSecondary : .loopedTextPrimary,
                                    iconSize: 18,
                                    showsDisclosure: true,
                                    showsCommunityFallback: false
                                )
                                .padding(12)
                                .background(Color.loopedTextSecondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isSaving)

                            if let displaySpecializationError {
                                Text(displaySpecializationError)
                                    .font(.loopedSmallText)
                                    .foregroundColor(.loopedError)
                            }
                        }
                        .padding(.horizontal, 20)

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
                    }

                    // Save Button
                    Button(action: saveProfile) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .loopedWhite))
                            }
                            Text(isSaving ? "Saving..." : "Save Changes")
                                .font(.loopedBodyStrong)
                        }
                        .foregroundColor(.loopedWhite)
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
                            .foregroundColor(.loopedError)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 100)
            }
            }

        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .toast($toastMessage)
        .sheet(isPresented: $isShowingSpecializationPicker) {
            DisplaySpecializationPickerView(selectedSpecialization: $displaySpecialization)
        }
        .sheet(isPresented: $isShowingAnonSpecializationPicker) {
            DisplaySpecializationPickerView(selectedSpecialization: $anonDisplaySpecialization)
        }
        .onAppear {
            hydrateFromUser()
            Task { await loadVerifiedCommunities() }
            if isAnonymousMode {
                Task { await loadAnonDisplayCommunities() }
            }
        }
        .onChange(of: authViewModel.currentUser?.id) { _ in
            hasLoadedUser = false
            hydrateFromUser()
            Task { await loadVerifiedCommunities() }
            if isAnonymousMode {
                Task { await loadAnonDisplayCommunities() }
            }
        }
        .onChange(of: displaySpecialization?.id) { _, _ in
            displaySpecializationError = nil
        }
        .onChange(of: anonDisplaySpecialization?.id) { _, _ in
            anonDisplaySpecializationError = nil
        }
        .onChange(of: isAnonymousMode) { _, newValue in
            if newValue {
                profilePhotoPayload = nil
                selectedProfilePhoto = nil
                profilePhotoPreview = nil
                Task { await loadAnonDisplayCommunities() }
            } else {
                anonDisplayCommunityId = nil
                initialAnonDisplayCommunityId = nil
                anonDisplayCommunityError = nil
                anonDisplayCommunities = []
                anonHandle = nil
                anonDisplaySpecialization = nil
                initialAnonDisplaySpecializationId = nil
                anonDisplaySpecializationError = nil
            }
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

	    var anonFormattedHandle: String {
	        let trimmed = (anonHandle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
	        return "@\(trimmed.isEmpty ? "anonymous" : trimmed)"
	    }

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

    var selectedAnonDisplayCommunity: DisplayCommunity? {
        guard let id = anonDisplayCommunityId else { return nil }
        if let community = anonDisplayCommunities.first(where: { $0.id == id }) {
            return community
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
        displaySpecialization = user.displaySpecialization
        initialDisplaySpecializationId = user.displaySpecialization?.id
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

    func loadAnonDisplayCommunities() async {
        guard !isLoadingAnonDisplayCommunities else { return }
        isLoadingAnonDisplayCommunities = true
        anonDisplayCommunityError = nil
        defer { isLoadingAnonDisplayCommunities = false }

        do {
            let identity: AnonIdentity
            if let existing = anonService.currentIdentity() {
                identity = existing
            } else {
                let communityId = await AnonCommunityResolver.resolve(
                    preferredCommunityId: currentUser?.displayCommunity?.id,
                    verificationService: verificationService
                )
                guard let communityId else {
                    throw AnonServiceError.missingCommunityContext
                }
                identity = try await anonService.ensureIdentity(communityId: communityId)
            }
            anonHandle = identity.handle
            let profile = try? await anonService.fetchProfile(id: identity.profileId)
            anonDisplayCommunityId = profile?.displayCommunity?.id
            initialAnonDisplayCommunityId = anonDisplayCommunityId
            anonDisplaySpecialization = profile?.displaySpecialization
            initialAnonDisplaySpecializationId = profile?.displaySpecialization?.id

            let memberships = await anonService.currentMemberships()
            guard !memberships.isEmpty else {
                anonDisplayCommunities = []
                return
            }
            let verifications = try? await verificationService.fetchCommunityVerifications()
            let verificationMap = Dictionary(
                uniqueKeysWithValues: (verifications ?? []).map { ($0.communityId, $0) }
            )
            anonDisplayCommunities = memberships.keys.sorted().map { communityId in
                if let verification = verificationMap[communityId] {
                    return DisplayCommunity(verification: verification)
                }
                return DisplayCommunity(
                    id: communityId,
                    name: "Community \(communityId)",
                    kind: .unknown,
                    specializationType: nil
                )
            }
        } catch {
            anonDisplayCommunityError = error.localizedDescription
            anonDisplayCommunities = []
            anonHandle = nil
            anonDisplaySpecialization = nil
            initialAnonDisplaySpecializationId = nil
        }
    }

    func saveProfile() {
        guard !isSaving else { return }
        if isAnonymousMode {
            saveAnonymousProfile()
            return
        }
        guard isFormValid else { return }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        saveError = nil
        displayCommunityError = nil
        displaySpecializationError = nil
        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                var profileMediaAssetId: Int?
                if let payload = profilePhotoPayload {
                    let asset = try await mediaService.uploadImage(
                        data: payload.data,
                        mimeType: payload.mimeType,
                        width: payload.width,
                        height: payload.height
                    )
                    profileMediaAssetId = asset.id
                }

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
                    showFollowerCount: nil,
                    messagePermission: authViewModel.currentUser?.messagePermission,
                    profileMediaAssetId: profileMediaAssetId
                )
                if displayCommunityId != initialDisplayCommunityId {
                    _ = try await userService.updateDisplayCommunity(communityId: displayCommunityId)
                    initialDisplayCommunityId = displayCommunityId
                }
                let displaySpecializationId = displaySpecialization?.id
                if displaySpecializationId != initialDisplaySpecializationId {
                    do {
                        _ = try await userService.updateDisplaySpecialization(specializationId: displaySpecializationId)
                        initialDisplaySpecializationId = displaySpecializationId
                    } catch {
                        displaySpecializationError = mapSaveError(error)
                        throw error
                    }
                }
                await authViewModel.loadCurrentUser()
                profilePhotoPayload = nil
                selectedProfilePhoto = nil
                profilePhotoPreview = nil
                presentToast(message: "Changes saved", kind: .success)
            } catch {
                saveError = mapSaveError(error)
                presentToast(message: "Changes not saved", kind: .error)
            }
        }
    }

    func saveAnonymousProfile() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        saveError = nil
        anonDisplayCommunityError = nil
        anonDisplaySpecializationError = nil
        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                var updatedProfile: AnonProfile?
                if anonDisplayCommunityId != initialAnonDisplayCommunityId {
                    updatedProfile = try await anonService.updateDisplayCommunity(communityId: anonDisplayCommunityId)
                    anonDisplayCommunityId = updatedProfile?.displayCommunity?.id
                    initialAnonDisplayCommunityId = anonDisplayCommunityId
                }
                let specializationId = anonDisplaySpecialization?.id
                if specializationId != initialAnonDisplaySpecializationId {
                    do {
                        updatedProfile = try await anonService.updateDisplaySpecialization(specializationId: specializationId)
                        anonDisplaySpecialization = updatedProfile?.displaySpecialization
                        initialAnonDisplaySpecializationId = specializationId
                    } catch {
                        anonDisplaySpecializationError = mapSaveError(error)
                        throw error
                    }
                }
                presentToast(message: "Changes saved", kind: .success)
            } catch {
                saveError = mapSaveError(error)
                presentToast(message: "Changes not saved", kind: .error)
            }
        }
    }

    var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isFormValid: Bool {
        if isAnonymousMode { return true }
        return isUsernameReady
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

    func mapSaveError(_ error: Error) -> String {
        if case let APIError.apiError(_, apiError, message) = error {
            switch apiError {
            case "user_not_provisioned":
                return "Your account isn't fully onboarded yet."
            case "media_asset_not_found":
                return "That photo couldn't be found. Try uploading again."
            case "media_asset_forbidden":
                return "That photo isn't linked to your account. Try uploading again."
            case "invalid_profile_image":
                return "That file isn't a supported image type."
            case "cdn_not_configured":
                return "Profile photos are temporarily unavailable. Try again later."
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
            case "specialization_not_found":
                return "That specialization could not be found."
            case "invalid_specialization":
                return "Select a major or department to display."
            case "specialization_not_joined":
                return "You must join that major or department to display it."
            case "invalid_anon_proof":
                return "Anonymous identity proof failed. Try toggling anonymous mode off/on."
            case "anon_jwt_not_allowed":
                return "Anonymous updates can’t use your login session. Please try again."
            default:
                if let message, !message.isEmpty {
                    return message
                }
                return apiError
            }
        }
        return error.localizedDescription
    }

    func presentToast(message: String, kind: ToastKind = .info) {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = ToastMessage(text: message, kind: kind)
        }
    }

    @MainActor
    private func handleProfilePhotoSelection(_ newValue: PhotosPickerItem?) async {
        guard let newValue else { return }
        do {
            guard let data = try await newValue.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                presentToast(message: "Couldn't read that photo. Try another one.", kind: .error)
                return
            }
            profilePhotoPreview = image
            profilePhotoPayload = makeUploadPayload(from: image)
        } catch {
            presentToast(message: "Couldn't load that photo. Try another one.", kind: .error)
        }
    }

    private func makeUploadPayload(from image: UIImage) -> ImageUploadPayload? {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        if imageHasAlpha(image), let pngData = image.pngData() {
            return ImageUploadPayload(data: pngData, mimeType: "image/png", width: width, height: height)
        }

        if let jpegData = image.jpegData(compressionQuality: 0.85) {
            return ImageUploadPayload(data: jpegData, mimeType: "image/jpeg", width: width, height: height)
        }

        return nil
    }

    private func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}

private struct ImageUploadPayload {
    let data: Data
    let mimeType: String
    let width: Int
    let height: Int
}

#Preview {
    UserSettingsView()
        .environmentObject(AuthViewModel())
}
