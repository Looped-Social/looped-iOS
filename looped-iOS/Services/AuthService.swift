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

    // ASAuthorizationController does not strongly retain its delegate/presentationContextProvider.
    // Keep these alive for the duration of an in-flight Apple authorization request.
    private var appleAuthController: ASAuthorizationController?
    private var appleAuthDelegate: AppleAuthDelegate?
    
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
            if let resolver = mfaResolver(from: error) {
                throw MFARequiredError(resolver: resolver)
            }
            throw mapFirebaseAuthError(error)
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
            throw mapFirebaseAuthError(error)
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
        do {
            _ = try await Auth.auth().signIn(with: credential)
            _isAuthenticated = true
            if let token = try await currentIDToken() {
                tokenStorage.token = token
            }
        } catch {
            if let resolver = mfaResolver(from: error) {
                throw MFARequiredError(resolver: resolver)
            }
            throw mapFirebaseAuthError(error)
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

    func unlinkGoogle() async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw AuthError.invalidCredentials
        }
        _ = try await user.unlink(fromProvider: "google.com")
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
        do {
            _ = try await Auth.auth().signIn(with: oauthCredential)
            _isAuthenticated = true
            if let token = try await currentIDToken() {
                tokenStorage.token = token
            }
        } catch {
            if let resolver = mfaResolver(from: error) {
                throw MFARequiredError(resolver: resolver)
            }
            throw mapFirebaseAuthError(error)
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

    func unlinkApple() async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw AuthError.invalidCredentials
        }
        _ = try await user.unlink(fromProvider: "apple.com")
        if let token = try await currentIDToken() {
            tokenStorage.token = token
        }
        #else
        throw AuthError.networkError
        #endif
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
        do {
            _ = try await Auth.auth().signIn(with: oauthCredential)
            _isAuthenticated = true
            if let token = try await currentIDToken() {
                tokenStorage.token = token
            }
        } catch {
            if let resolver = mfaResolver(from: error) {
                throw MFARequiredError(resolver: resolver)
            }
            throw mapFirebaseAuthError(error)
        }
    }

    #if canImport(FirebaseAuth)
    func sendMfaCode(resolver: MultiFactorResolver, hint: PhoneMultiFactorInfo) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            PhoneAuthProvider.provider().verifyPhoneNumber(
                with: hint,
                uiDelegate: nil,
                multiFactorSession: resolver.session
            ) { verificationID, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let verificationID {
                    continuation.resume(returning: verificationID)
                } else {
                    continuation.resume(throwing: AuthError.invalidCredentials)
                }
            }
        }
    }

    func resolveMfaSignIn(
        resolver: MultiFactorResolver,
        verificationId: String,
        verificationCode: String
    ) async throws {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId,
            verificationCode: verificationCode
        )
        let assertion = PhoneMultiFactorGenerator.assertion(with: credential)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            resolver.resolveSignIn(with: assertion) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
        _isAuthenticated = true
        if let token = try await currentIDToken() {
            tokenStorage.token = token
        }
    }
    #endif
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

    func mapFirebaseAuthError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        if let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidEmail:
                return .invalidEmail
            case .emailAlreadyInUse:
                return .emailAlreadyInUse
            case .weakPassword:
                return .weakPassword
            case .userNotFound:
                return .userNotFound
            case .wrongPassword:
                return .wrongPassword
            case .userDisabled:
                return .userDisabled
            case .networkError:
                return .networkError
            default:
                break
            }
        }
        return .invalidCredentials
    }

    func mfaResolver(from error: Error) -> MultiFactorResolver? {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code), code == .secondFactorRequired else {
            return nil
        }
        return nsError.userInfo[AuthErrorUserInfoMultiFactorResolverKey] as? MultiFactorResolver
    }
    #endif
}

#if canImport(FirebaseAuth)
struct MFARequiredError: Error {
    let resolver: MultiFactorResolver
}
#endif

enum AuthError: Error, LocalizedError {
    case noRefreshToken
    case invalidCredentials
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case userNotFound
    case wrongPassword
    case userDisabled
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidCredentials:
            return "Invalid email or password"
        case .invalidEmail:
            return "Enter a valid email address."
        case .weakPassword:
            return "Password is too weak. Use 8+ characters with a number, uppercase letter, and special character."
        case .emailAlreadyInUse:
            return "An account already exists for this email."
        case .userNotFound:
            return "No account found for this email."
        case .wrongPassword:
            return "Incorrect password."
        case .userDisabled:
            return "This account has been disabled."
        case .networkError:
            return "Network error occurred"
        }
    }
}

// MARK: - Apple Sign-in Helpers
private extension AuthService {
    func performAppleAuthorization(request: ASAuthorizationAppleIDRequest, anchor: ASPresentationAnchor) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor [weak self] in
                guard let self else {
                    continuation.resume(throwing: AuthError.networkError)
                    return
                }

                var didResume = false
                let controller = ASAuthorizationController(authorizationRequests: [request])
                let delegate = AppleAuthDelegate(anchor: anchor) { [weak self] result in
                    guard !didResume else { return }
                    didResume = true

                    switch result {
                    case .success(let credential):
                        continuation.resume(returning: credential)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }

                    self?.appleAuthController = nil
                    self?.appleAuthDelegate = nil
                }

                self.appleAuthController = controller
                self.appleAuthDelegate = delegate
                controller.delegate = delegate
                controller.presentationContextProvider = delegate
                controller.performRequests()
            }
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
