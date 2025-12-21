import Foundation
import Combine
import UIKit
import AuthenticationServices
import CryptoKit
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
    @Published var showDeferredOnboardingAlert = false
    @Published var shouldEnterOnboardingFlow = false
    @Published var selectedOrganization: Organization?
    @Published private(set) var linkedProviders: Set<String> = []
    
    private let authService: AuthServiceProtocol
    private let userService: UserServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        authService: AuthServiceProtocol = AuthService(),
        userService: UserServiceProtocol = UserService()
    ) {
        self.authService = authService
        self.userService = userService
        self.isAuthenticated = authService.isAuthenticated
        
        authService.authStateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
                if isAuthenticated {
                    Task { await self?.loadCurrentUser() }
                } else {
                    self?.currentUser = nil
                }
                self?.updateLinkedProviders()
            }
            .store(in: &cancellables)

        if authService.isAuthenticated {
            Task { await loadCurrentUser() }
        }
        updateLinkedProviders()
    }
    
    func login(email: String, password: String) async {
        shouldEnterOnboardingFlow = false
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.login(email: email, password: password)

            do {
                let user = try await userService.getCurrentUser()
                currentUser = user
                onboardingComplete = true
                if user.isVerified == false {
                    showDeferredOnboardingAlert = true
                }
            } catch UserServiceError.userNotProvisioned {
                showDeferredOnboardingAlert = true
                currentUser = nil
                onboardingComplete = true
            } catch {
                // Login succeeded; if user fetch fails (network/server), keep them signed in.
                showDeferredOnboardingAlert = true
                currentUser = nil
                onboardingComplete = true
            }
        } catch {
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign in with Apple (pure SwiftUI button flow)
    private var appleRawNonce: String?

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let rawNonce = randomNonceString()
        appleRawNonce = rawNonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(rawNonce)
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
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        authService.signOut()
        currentUser = nil
        onboardingComplete = false
        shouldEnterOnboardingFlow = true
        Task { await AnonService.shared.clearIdentity() }
        UserDefaults.standard.set(false, forKey: "anonymousMode")
        linkedProviders = []
    }

    func loadCurrentUser() async {
        do {
            let user = try await userService.getCurrentUser()
            currentUser = user
            if shouldEnterOnboardingFlow == false {
                onboardingComplete = true
            }
            errorMessage = nil
            updateLinkedProviders()
        } catch {
            errorMessage = error.localizedDescription
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

    var isGoogleLinked: Bool {
        linkedProviders.contains("google.com")
    }

    var isAppleLinked: Bool {
        linkedProviders.contains("apple.com")
    }
}

// MARK: - Nonce helpers for Apple
private extension AuthViewModel {
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }

            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }

    func updateLinkedProviders() {
        #if canImport(FirebaseAuth)
        let providers = Auth.auth().currentUser?.providerData.map { $0.providerID } ?? []
        linkedProviders = Set(providers)
        #else
        linkedProviders = []
        #endif
    }
}
