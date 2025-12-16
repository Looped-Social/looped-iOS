import Foundation
import Combine
import UIKit
import AuthenticationServices
import CryptoKit

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var onboardingComplete = false
    
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
            }
            .store(in: &cancellables)

        if authService.isAuthenticated {
            Task { await loadCurrentUser() }
        }
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.login(email: email, password: password)
            await loadCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(
                email: email,
                password: password,
                username: username
            )
            await loadCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Google Sign-In (triggered from View)
    func signInWithGoogle() async {
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
    }

    func loadCurrentUser() async {
        do {
            let user = try await userService.getCurrentUser()
            currentUser = user
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
}
