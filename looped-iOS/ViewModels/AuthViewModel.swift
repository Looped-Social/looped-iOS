import Foundation
import Combine
import UIKit
import AuthenticationServices
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var onboardingComplete = false
    @Published var shouldEnterOnboardingFlow = false
    @Published var onboardingStep: RemoteOnboardingStep?
    @Published var onboardingStageV2: String?
    @Published var onboardingContextV2: OnboardingContextV2DTO?
    @Published var profileCompletionStatus: ProfileCompletionStatus?
    @Published var onboardingAllowedNextStagesV2: [String] = []
    @Published private(set) var didLoadIdentity = false
    @Published private(set) var isProvisioned = false
    @Published var selectedOrganization: Organization?
    @Published private(set) var linkedProviders: Set<String> = []
    #if canImport(FirebaseAuth)
    @Published var mfaSession: MFAChallengeSession?
    #endif
    
    private let authService: AuthServiceProtocol
    private let userService: UserServiceProtocol
    private let deviceRegistrar: NotificationDeviceRegistrar
    private let notificationService: NotificationServiceProtocol
    private let onboardingStore = OnboardingProgressStore()
    private let onboardingScopeUserDefaultsKey = "looped.onboarding.lastAuthUID"
    private var cancellables = Set<AnyCancellable>()
    
    init(
        authService: AuthServiceProtocol = AuthService(),
        userService: UserServiceProtocol = UserService(),
        deviceRegistrar: NotificationDeviceRegistrar = .shared,
        notificationService: NotificationServiceProtocol = NotificationService()
    ) {
        self.authService = authService
        self.userService = userService
        self.deviceRegistrar = deviceRegistrar
        self.notificationService = notificationService
        self.isAuthenticated = authService.isAuthenticated
        self.didLoadIdentity = !authService.isAuthenticated
        self.deviceRegistrar.updateAuthState(isAuthenticated: authService.isAuthenticated)
        syncOnboardingScopeForCurrentAuthUser(clearPrevious: true)
        syncTelemetryAuthState()
        
        authService.authStateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self else { return }
                self.syncOnboardingScopeForCurrentAuthUser(clearPrevious: true)
                self.isAuthenticated = isAuthenticated
                self.deviceRegistrar.updateAuthState(isAuthenticated: isAuthenticated)
                if isAuthenticated {
                    self.didLoadIdentity = false
                    Task { await self.bootstrapIdentity() }
                } else {
                    self.currentUser = nil
                    self.onboardingComplete = false
                    self.onboardingStep = nil
                    self.onboardingStageV2 = nil
                    self.onboardingContextV2 = nil
                    self.profileCompletionStatus = nil
                    self.onboardingAllowedNextStagesV2 = []
                    self.isProvisioned = false
                    self.selectedOrganization = nil
                    self.shouldEnterOnboardingFlow = true
                    self.didLoadIdentity = true
                }
                self.updateLinkedProviders()
                self.syncTelemetryAuthState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .authGatingRequired)
            .compactMap { $0.object as? AuthGatingContext }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] context in
                self?.handleAuthGating(context)
            }
            .store(in: &cancellables)

        updateLinkedProviders()
    }
    
    func login(email: String, password: String) async {
        shouldEnterOnboardingFlow = false
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.login(email: email, password: password)
            await loadCurrentUser()
        } catch {
            #if canImport(FirebaseAuth)
            if handleMfaRequired(error) {
                isLoading = false
                return
            }
            #endif
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String) async {
        shouldEnterOnboardingFlow = true
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(email: email, password: password)
            await loadCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    func sendPasswordReset(email: String) async throws {
        try await authService.sendPasswordReset(email: email)
    }

    func enableNotificationsDuringOnboarding(wantsRecommendations: Bool) async {
        let granted = await NotificationAuthorizationManager.shared.requestAuthorization()
        guard granted else { return }
        do {
            var types = NotificationTypePreferencesUpdateDTO()
            types.postFromFollowed = wantsRecommendations
            let update = NotificationPreferencesUpdateRequest(
                channels: NotificationChannelsUpdateDTO(
                    inApp: nil,
                    push: NotificationChannelUpdateDTO(enabled: true, types: types),
                    email: nil
                )
            )
            _ = try await notificationService.updatePreferences(update)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finishOnboardingFromNotificationsStep() async {
        await reportOnboardingStep(.verificationNotifications)

        // If the backend marked onboarding complete, `reportOnboardingStep` already refreshed identity.
        if onboardingComplete {
            shouldEnterOnboardingFlow = false
            return
        }

        // Best-effort: if we haven't confirmed provisioning yet, refresh once.
        if !isProvisioned {
            await loadCurrentUser()
        }

        guard isProvisioned else { return }

        // Fallback: don't block the UI on eventual-consistency for `onboardingComplete`.
        onboardingComplete = true
        onboardingStep = .verificationNotifications
        shouldEnterOnboardingFlow = false
    }
    
    // MARK: - Google Sign-In (triggered from View)
    func signInWithGoogle() async {
        shouldEnterOnboardingFlow = true
        isLoading = true
        errorMessage = nil
        do {
            guard let vc = UIHelpers.topViewController() else {
                throw AuthError.networkError
            }
            try await authService.signInWithGoogle(presenting: vc)
            await loadCurrentUser()
        } catch {
            #if canImport(FirebaseAuth)
            if handleMfaRequired(error) {
                isLoading = false
                return
            }
            #endif
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signInWithApple() async {
        shouldEnterOnboardingFlow = true
        isLoading = true
        errorMessage = nil
        do {
            guard let anchor = UIHelpers.currentPresentationAnchor() else {
                throw AuthError.networkError
            }
            try await authService.signInWithApple(presentationAnchor: anchor)
            await loadCurrentUser()
        } catch {
            #if canImport(FirebaseAuth)
            if handleMfaRequired(error) {
                isLoading = false
                return
            }
            #endif
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign in with Apple (pure SwiftUI button flow)
    private var appleRawNonce: String?

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let rawNonce = AppleSignInUtilities.randomNonceString()
        appleRawNonce = rawNonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInUtilities.sha256(rawNonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        shouldEnterOnboardingFlow = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let rawNonce = appleRawNonce else {
                errorMessage = AuthError.invalidCredentials.localizedDescription
                return
            }
            do {
                try await authService.signInWithApple(credential: credential, rawNonce: rawNonce)
                persistAppleNameDraft(from: credential)
                await loadCurrentUser()
            } catch {
                #if canImport(FirebaseAuth)
                if handleMfaRequired(error) {
                    return
                }
                #endif
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            #if canImport(FirebaseAuth)
            if handleMfaRequired(error) {
                return
            }
            #endif
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        authService.signOut()
        syncOnboardingScopeForCurrentAuthUser(clearPrevious: true)
        currentUser = nil
        onboardingComplete = false
        onboardingStep = nil
        onboardingStageV2 = nil
        onboardingContextV2 = nil
        profileCompletionStatus = nil
        onboardingAllowedNextStagesV2 = []
        isProvisioned = false
        shouldEnterOnboardingFlow = true
        Task { await AnonService.shared.clearIdentity() }
        UserDefaults.standard.set(false, forKey: "anonymousMode")
        FollowStateStore.shared.reset()
        linkedProviders = []
        #if canImport(FirebaseAuth)
        mfaSession = nil
        #endif
        onboardingStore.clearAll()
        syncTelemetryAuthState()
    }

    func loadCurrentUser() async {
        syncOnboardingScopeForCurrentAuthUser(clearPrevious: true)
        do {
            let identity = try await userService.getIdentity()
            onboardingComplete = identity.onboardingComplete ?? (identity.provisioned && identity.user != nil)
            isProvisioned = identity.provisioned || onboardingComplete
            onboardingStep = onboardingComplete ? nil : (identity.onboardingStep ?? .profileSetup)
            onboardingStageV2 = identity.onboardingStageV2
            onboardingContextV2 = identity.onboardingContext
            profileCompletionStatus = identity.profileCompletion.map(ProfileCompletionStatus.init(dto:))
            onboardingAllowedNextStagesV2 = []
            shouldEnterOnboardingFlow = !onboardingComplete

            if let userDTO = identity.user {
                currentUser = User(dto: userDTO, profile: userDTO.profile)
                if onboardingComplete {
                    currentUser = try await userService.getCurrentUser()
                }
            } else {
                currentUser = nil
            }

            errorMessage = nil
            updateLinkedProviders()
            syncTelemetryAuthState()
        } catch UserServiceError.userNotProvisioned {
            shouldEnterOnboardingFlow = true
            onboardingComplete = false
            onboardingStep = .profileSetup
            onboardingStageV2 = nil
            onboardingContextV2 = nil
            profileCompletionStatus = nil
            onboardingAllowedNextStagesV2 = []
            isProvisioned = false
            currentUser = nil
            selectedOrganization = nil
            onboardingStore.clearAll()
            errorMessage = nil
            syncTelemetryAuthState()
        } catch let apiError as APIError where apiError.isAuthGatingError {
            // Centralized gating handling is applied via NotificationCenter.
            errorMessage = nil
            syncTelemetryAuthState()
        } catch {
            errorMessage = error.localizedDescription
            syncTelemetryAuthState()
        }
    }

    private func bootstrapIdentity() async {
        defer { didLoadIdentity = true }
        await loadCurrentUser()
    }

    func checkUsernameAvailability(_ username: String) async throws -> UsernameAvailabilityResponseDTO {
        try await userService.checkUsernameAvailability(username)
    }

    func onboardUser(username: String, firstName: String, lastName: String, dateOfBirth: Date) async throws {
        let dob = dateOfBirth.yyyyMMddString()
        let user = try await userService.onboardUser(
            username: username,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dob
        )
        currentUser = user
        isProvisioned = true
        updateLinkedProviders()
    }

    func updateIdentity(username: String, firstName: String, lastName: String, dateOfBirth: Date) async throws {
        let dob = dateOfBirth.yyyyMMddString()
        let user = try await userService.updateIdentity(
            username: username,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dob
        )
        currentUser = user
        isProvisioned = true
        updateLinkedProviders()
    }

    func reportOnboardingStep(_ step: RemoteOnboardingStep) async {
        guard isAuthenticated else { return }
        do {
            let state = try await userService.updateOnboardingStep(step)
            onboardingComplete = state.onboardingComplete
            onboardingStep = state.onboardingStep
            shouldEnterOnboardingFlow = !state.onboardingComplete

            if onboardingComplete {
                await loadCurrentUser()
            }
        } catch let APIError.apiError(_, apiError, _) where apiError == "user_not_provisioned" {
            // Ignore: user hasn't completed initial /v1/users/onboard yet.
        } catch let apiError as APIError where apiError.isAuthGatingError {
            // Ignore: centralized gating handler updates auth routing.
        } catch {
            // Ignore: onboarding step reporting shouldn't block the UI.
        }
    }

    func markOnboardingInfoScreenViewed() async -> Bool {
        await performOnboardingV2Update {
            try await userService.markOnboardingInfoScreenViewed()
        }
    }

    var shouldPromptProfileCompletion: Bool {
        isAuthenticated && onboardingComplete && (profileCompletionStatus?.shouldPrompt ?? false)
    }

    func dismissProfileCompletionPrompt() async -> Bool {
        guard isAuthenticated else { return false }
        do {
            let response = try await userService.dismissProfileCompletionPrompt()
            if let response {
                profileCompletionStatus = ProfileCompletionStatus(dto: response)
            } else if let profileCompletionStatus {
                self.profileCompletionStatus = profileCompletionStatus.dismissing()
            }
            errorMessage = nil
            return true
        } catch let apiError as APIError where apiError.isAuthGatingError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func setOnboardingV2Organization(orgId: Int) async -> Bool {
        await performOnboardingV2Update {
            try await userService.setOnboardingV2Organization(orgId: orgId)
        }
    }

    func setOnboardingV2VerificationChoice(path: String) async -> Bool {
        await performOnboardingV2Update {
            try await userService.setOnboardingV2VerificationChoice(path: path)
        }
    }

    func markOnboardingV2EmailVerificationSuccess() async -> Bool {
        await performOnboardingV2Update {
            try await userService.markOnboardingV2EmailVerificationSuccess()
        }
    }

    func submitOnboardingV2Specialization(specializationId: Int) async -> Bool {
        await performOnboardingV2Update {
            try await userService.submitOnboardingV2Specialization(specializationId: specializationId)
        }
    }

    func acknowledgeOnboardingV2SkipExplainer() async -> Bool {
        await performOnboardingV2Update {
            try await userService.acknowledgeOnboardingV2SkipExplainer()
        }
    }

    func acknowledgeOnboardingV2PhotoPendingExplainer() async -> Bool {
        await performOnboardingV2Update {
            try await userService.acknowledgeOnboardingV2PhotoPendingExplainer()
        }
    }

    func finalizeOnboardingV2() async -> Bool {
        await performOnboardingV2Update {
            try await userService.finalizeOnboardingV2()
        }
    }

    func completeOnboardingAfterCommunityRequest() async -> Bool {
        await performOnboardingV2Update {
            try await userService.completeOnboardingV2AfterCommunityRequest()
        }
    }

    func linkGoogle() async throws {
        guard let vc = UIHelpers.topViewController() else {
            throw AuthError.networkError
        }
        try await authService.linkWithGoogle(presenting: vc)
        updateLinkedProviders()
    }

    func linkApple() async throws {
        guard let anchor = UIHelpers.currentPresentationAnchor() else {
            throw AuthError.networkError
        }
        try await authService.linkWithApple(presentationAnchor: anchor)
        updateLinkedProviders()
    }

    func unlinkGoogle() async throws {
        try await authService.unlinkGoogle()
        updateLinkedProviders()
    }

    func unlinkApple() async throws {
        try await authService.unlinkApple()
        updateLinkedProviders()
    }

    func refreshLinkedProviders() {
        updateLinkedProviders()
    }

    #if canImport(FirebaseAuth)
    func sendMfaCode(session: MFAChallengeSession, hintId: String) async throws -> String {
        guard let hint = session.phoneHints.first(where: { $0.uid == hintId }) else {
            throw AuthError.invalidCredentials
        }
        return try await authService.sendMfaCode(resolver: session.resolver, hint: hint)
    }

    func resolveMfaSignIn(session: MFAChallengeSession, verificationId: String, code: String) async throws {
        try await authService.resolveMfaSignIn(
            resolver: session.resolver,
            verificationId: verificationId,
            verificationCode: code
        )
        mfaSession = nil
    }

    func dismissMfa() {
        mfaSession = nil
    }
    #endif

    var isGoogleLinked: Bool {
        linkedProviders.contains("google.com")
    }

    var isAppleLinked: Bool {
        linkedProviders.contains("apple.com")
    }

    var isEmailPasswordLinked: Bool {
        linkedProviders.contains("password")
    }

    var emailForEmailPasswordLogin: String {
        guard isEmailPasswordLinked else { return "" }
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.email ?? ""
        #else
        return ""
        #endif
    }

    var authProviderDisplayName: String? {
        #if canImport(FirebaseAuth)
        let trimmed = (Auth.auth().currentUser?.displayName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
        #else
        return nil
        #endif
    }

    private func performOnboardingV2Update(
        _ operation: () async throws -> OnboardingStateV2DTO
    ) async -> Bool {
        guard isAuthenticated else { return false }
        do {
            let state = try await operation()
            await applyOnboardingV2State(state)
            return true
        } catch {
            if let apiError = error as? APIError, apiError.isAuthGatingError {
                return false
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func applyOnboardingV2State(_ state: OnboardingStateV2DTO) async {
        onboardingComplete = state.onboardingComplete
        if let step = state.onboardingStep {
            onboardingStep = step
        } else if state.onboardingComplete {
            onboardingStep = nil
        }
        onboardingStageV2 = state.onboardingStageV2
        onboardingContextV2 = state.onboardingContext
        onboardingAllowedNextStagesV2 = []
        shouldEnterOnboardingFlow = !state.onboardingComplete

        if state.onboardingComplete {
            await loadCurrentUser()
        } else {
            profileCompletionStatus = nil
        }
    }
}

// MARK: - Nonce helpers for Apple
private extension AuthViewModel {
    func handleAuthGating(_ context: AuthGatingContext) {
        guard isAuthenticated else { return }
        syncOnboardingScopeForCurrentAuthUser(clearPrevious: true)

        switch context.code {
        case .userNotProvisioned:
            onboardingComplete = false
            shouldEnterOnboardingFlow = true
            onboardingStep = .profileSetup
            onboardingStageV2 = nil
            onboardingContextV2 = nil
            profileCompletionStatus = nil
            onboardingAllowedNextStagesV2 = []
            isProvisioned = false
            currentUser = nil
            selectedOrganization = nil
            errorMessage = nil
            onboardingStore.clearAll()
        case .onboardingIncomplete:
            onboardingComplete = false
            shouldEnterOnboardingFlow = true
            onboardingStep = context.onboardingStep ?? context.currentStep ?? .profileSetup
            onboardingStageV2 = context.currentStageV2
            onboardingAllowedNextStagesV2 = context.allowedNextStagesV2 ?? []
            profileCompletionStatus = nil
            isProvisioned = true
            errorMessage = nil
        case .invalidOnboardingStep, .invalidOnboardingStage:
            onboardingComplete = false
            shouldEnterOnboardingFlow = true
            onboardingStep = context.currentStep ?? context.onboardingStep ?? .profileSetup
            onboardingStageV2 = context.currentStageV2
            onboardingAllowedNextStagesV2 = context.allowedNextStagesV2 ?? []
            profileCompletionStatus = nil
            isProvisioned = true
            errorMessage = nil
        case .accountDeleted:
            UserDefaults.standard.set(true, forKey: "showAccountDeletedAlert")
            errorMessage = nil
            signOut()
            return
        }
        syncTelemetryAuthState()
    }

    var persistedOnboardingScopeUserId: String? {
        get {
            UserDefaults.standard.string(forKey: onboardingScopeUserDefaultsKey)
        }
        set {
            let trimmed = (newValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: onboardingScopeUserDefaultsKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: onboardingScopeUserDefaultsKey)
            }
        }
    }

    func currentAuthUserId() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }

    func syncOnboardingScopeForCurrentAuthUser(clearPrevious: Bool) {
        let currentUserId = currentAuthUserId()
        let previousUserId = persistedOnboardingScopeUserId
        onboardingStore.setActiveUserId(currentUserId)
        if let currentUserId {
            let shouldMigrateLegacyScope = (previousUserId == nil || previousUserId == currentUserId)
            if shouldMigrateLegacyScope {
                onboardingStore.migrateLegacyGlobalScopeIfNeeded(toUserId: currentUserId)
            }
            onboardingStore.clearLegacyGlobalScope()
        }

        guard clearPrevious else {
            persistedOnboardingScopeUserId = currentUserId
            return
        }

        if let previousUserId, previousUserId != currentUserId {
            onboardingStore.clearAll(forUserId: previousUserId)
        }
        persistedOnboardingScopeUserId = currentUserId
    }

    func updateLinkedProviders() {
        #if canImport(FirebaseAuth)
        let providers = Auth.auth().currentUser?.providerData.map { $0.providerID } ?? []
        linkedProviders = Set(providers)
        #else
        linkedProviders = []
        #endif
    }

    func syncTelemetryAuthState() {
        let isAuthenticated = self.isAuthenticated
        let onboardingComplete = self.onboardingComplete
        Task {
            await TelemetryManager.shared.updateAuthState(
                isAuthenticated: isAuthenticated,
                onboardingComplete: onboardingComplete
            )
        }
    }

    func persistAppleNameDraft(from credential: ASAuthorizationAppleIDCredential) {
        let givenName = normalizedNonEmpty(credential.fullName?.givenName)
        let familyName = normalizedNonEmpty(credential.fullName?.familyName)
        let authProviderName = normalizedNonEmpty(authProviderDisplayName)

        var resolvedGivenName = givenName
        var resolvedFamilyName = familyName
        if (resolvedGivenName == nil || resolvedFamilyName == nil), let authProviderName {
            let parts = authProviderName
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            if resolvedGivenName == nil {
                resolvedGivenName = parts.first
            }
            if resolvedFamilyName == nil, parts.count > 1 {
                resolvedFamilyName = parts.dropFirst().joined(separator: " ")
            }
        }

        guard resolvedGivenName != nil || resolvedFamilyName != nil else { return }

        let existing = onboardingStore.loadProfileDraft()
        let draft = OnboardingProfileDraft(
            username: existing?.username ?? "",
            firstName: resolvedGivenName ?? existing?.firstName ?? "",
            lastName: resolvedFamilyName ?? existing?.lastName ?? "",
            dateOfBirth: existing?.dateOfBirth
        )
        onboardingStore.saveProfileDraft(draft)
    }

    func normalizedNonEmpty(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    #if canImport(FirebaseAuth)
    func handleMfaRequired(_ error: Error) -> Bool {
        if let mfaError = error as? MFARequiredError {
            let session = MFAChallengeSession(resolver: mfaError.resolver)
            if session.phoneHints.isEmpty {
                errorMessage = "Two-factor is enabled, but no phone number is available."
                return false
            }
            mfaSession = session
            errorMessage = nil
            return true
        }
        return false
    }
    #endif
}
