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
        
        authService.authStateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self else { return }
                self.isAuthenticated = isAuthenticated
                self.deviceRegistrar.updateAuthState(isAuthenticated: isAuthenticated)
                if isAuthenticated {
                    self.didLoadIdentity = false
                    Task { await self.bootstrapIdentity() }
                } else {
                    self.currentUser = nil
                    self.onboardingComplete = false
                    self.onboardingStep = nil
                    self.isProvisioned = false
                    self.selectedOrganization = nil
                    self.shouldEnterOnboardingFlow = true
                    self.didLoadIdentity = true
                }
                self.updateLinkedProviders()
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
        currentUser = nil
        onboardingComplete = false
        onboardingStep = nil
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
    }

    func loadCurrentUser() async {
        do {
            let identity = try await userService.getIdentity()
            isProvisioned = identity.provisioned
            onboardingComplete = identity.onboardingComplete ?? false
            onboardingStep = identity.onboardingStep
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
        } catch UserServiceError.userNotProvisioned {
            shouldEnterOnboardingFlow = true
            onboardingComplete = false
            onboardingStep = .profileSetup
            isProvisioned = false
            currentUser = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
        } catch {
            // Ignore: onboarding step reporting shouldn't block the UI.
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
}

// MARK: - Nonce helpers for Apple
private extension AuthViewModel {
    func updateLinkedProviders() {
        #if canImport(FirebaseAuth)
        let providers = Auth.auth().currentUser?.providerData.map { $0.providerID } ?? []
        linkedProviders = Set(providers)
        #else
        linkedProviders = []
        #endif
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
