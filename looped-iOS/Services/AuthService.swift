import Foundation
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import AuthenticationServices
import CryptoKit

class AuthService: AuthServiceProtocol {
    private let tokenStorage: TokenStorage
    
    @Published private var _isAuthenticated = false
    
    var authStateChanged: AnyPublisher<Bool, Never> {
        $_isAuthenticated.eraseToAnyPublisher()
    }
    
    var isAuthenticated: Bool {
        _isAuthenticated
    }
    
    init(tokenStorage: TokenStorage = TokenStorage()) {
        self.tokenStorage = tokenStorage
        #if canImport(FirebaseAuth)
        self._isAuthenticated = Auth.auth().currentUser != nil
        #else
        self._isAuthenticated = tokenStorage.hasValidToken()
        #endif
    }
    
    func login(email: String, password: String) async throws {
        #if canImport(FirebaseAuth)
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            _isAuthenticated = true
            // Optionally cache latest ID token for legacy consumers
            if let token = try await currentIDToken() {
                tokenStorage.token = token
            }
        } catch {
            throw AuthError.invalidCredentials
        }
        #else
        throw AuthError.networkError
        #endif
    }
    
    func signUp(email: String, password: String) async throws {
        #if canImport(FirebaseAuth)
        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
            _isAuthenticated = true
            if let token = try await currentIDToken() {
                tokenStorage.token = token
            }
        } catch {
            throw AuthError.invalidCredentials
        }
        #else
        throw AuthError.networkError
        #endif
    }

    func sendPasswordReset(email: String) async throws {
        #if canImport(FirebaseAuth)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
        #else
        throw AuthError.networkError
        #endif
    }
    
    func signOut() {
        #if canImport(FirebaseAuth)
        do { try Auth.auth().signOut() } catch { }
        #endif
        tokenStorage.clear()
        _isAuthenticated = false
    }
    
    func refreshToken() async throws {
        #if canImport(FirebaseAuth)
        if let token = try await currentIDToken(forcingRefresh: true) {
            tokenStorage.token = token
        }
        #else
        throw AuthError.noRefreshToken
        #endif
    }

    // MARK: - Google Sign-In
    func signInWithGoogle(presenting: UIViewController) async throws {
        #if canImport(GoogleSignIn)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredentials
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        _ = try await Auth.auth().signIn(with: credential)
        _isAuthenticated = true
        if let token = try await currentIDToken() {
            tokenStorage.token = token
        }
        #else
        throw AuthError.networkError
        #endif
    }

    func linkWithGoogle(presenting: UIViewController) async throws {
        #if canImport(GoogleSignIn)
        guard let user = Auth.auth().currentUser else {
            throw AuthError.invalidCredentials
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredentials
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        _ = try await user.link(with: credential)
        if let token = try await currentIDToken() {
            tokenStorage.token = token
        }
        #else
        throw AuthError.networkError
        #endif
    }

    // MARK: - Sign in with Apple
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        let nonce = randomNonceString()
        let hashedNonce = sha256(nonce)

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let credential = try await performAppleAuthorization(request: request, anchor: presentationAnchor)
        guard let appleIDToken = credential.identityToken, let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }
        let oauthCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        _ = try await Auth.auth().signIn(with: oauthCredential)
        _isAuthenticated = true
        if let token = try await currentIDToken() {
            tokenStorage.token = token
        }
    }

    func linkWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.invalidCredentials
        }
        let nonce = randomNonceString()
        let hashedNonce = sha256(nonce)

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let credential = try await performAppleAuthorization(request: request, anchor: presentationAnchor)
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }
        let oauthCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        _ = try await user.link(with: oauthCredential)
        if let token = try await currentIDToken() {
            tokenStorage.token = token
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }
        let oauthCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: credential.fullName
        )
        _ = try await Auth.auth().signIn(with: oauthCredential)
        _isAuthenticated = true
        if let token = try await currentIDToken() {
            tokenStorage.token = token
        }
    }
}

private extension AuthService {
    #if canImport(FirebaseAuth)
    func currentIDToken(forcingRefresh: Bool = false) async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(forcingRefresh) { token, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: token)
            }
        }
    }
    #endif
}

enum AuthError: Error, LocalizedError {
    case noRefreshToken
    case invalidCredentials
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error occurred"
        }
    }
}

// MARK: - Apple Sign-in Helpers
private extension AuthService {
    func performAppleAuthorization(request: ASAuthorizationAppleIDRequest, anchor: ASPresentationAnchor) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleAuthDelegate(anchor: anchor) { result in
                switch result {
                case .success(let credential):
                    continuation.resume(returning: credential)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }

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

private final class AppleAuthDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void

    init(anchor: ASPresentationAnchor, completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.anchor = anchor
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(credential))
        } else {
            completion(.failure(AuthError.invalidCredentials))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}
