import Foundation
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import AuthenticationServices

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

    #if canImport(GoogleSignIn)
    @MainActor
    private func performGoogleSignIn(presenting: UIViewController) async throws -> GIDSignInResult {
        try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
    }
    #endif

    // MARK: - Google Sign-In
    func signInWithGoogle(presenting: UIViewController) async throws {
        #if canImport(GoogleSignIn)
        let result = try await performGoogleSignIn(presenting: presenting)
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
        let result = try await performGoogleSignIn(presenting: presenting)
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
        try await unlinkProviderViaBackend(provider: "google")
    }

    // MARK: - Sign in with Apple
    func signInWithApple(presentationAnchor: ASPresentationAnchor) async throws {
        let nonce = AppleSignInUtilities.randomNonceString()
        let hashedNonce = AppleSignInUtilities.sha256(nonce)

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
        let nonce = AppleSignInUtilities.randomNonceString()
        let hashedNonce = AppleSignInUtilities.sha256(nonce)

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
        try await unlinkProviderViaBackend(provider: "apple")
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
    struct ProviderUnlinkErrorPayload: Decodable {
        let error: String
        let message: String?
        let reason: String?
        let code: String?
    }

    struct ProviderUnlinkSuccessPayload: Decodable {
        let provider: String?
        let unlinked: Bool?
    }

    func unlinkProviderViaBackend(provider: String) async throws {
        #if canImport(FirebaseAuth)
        guard Auth.auth().currentUser != nil else {
            throw AuthError.invalidCredentials
        }
        let idToken: String
        do {
            guard let token = try await currentIDToken(forcingRefresh: true) else {
                throw AuthError.sessionExpired
            }
            idToken = token
        } catch let authError as AuthError {
            throw authError
        } catch {
            throw mapUnlinkSessionError(error)
        }

        let url = LoopedEnvironment
            .apiBaseURL()
            .appendingPathComponent("v1")
            .appendingPathComponent("me")
            .appendingPathComponent("providers")
            .appendingPathComponent(provider)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        if 200...299 ~= httpResponse.statusCode {
            let successPayload = try? JSONDecoder().decode(ProviderUnlinkSuccessPayload.self, from: data)
            if successPayload?.unlinked == false {
                throw AuthError.providerUnlinkFailed(message: "That account is already disconnected.")
            }
            if let user = Auth.auth().currentUser {
                do {
                    try await reload(user: user)
                } catch {
                    throw mapPostUnlinkSessionError(error)
                }
            }
            do {
                if let refreshed = try await currentIDToken(forcingRefresh: true) {
                    tokenStorage.token = refreshed
                } else {
                    throw AuthError.providerDisconnectedRequiresSignIn
                }
            } catch let authError as AuthError {
                throw authError
            } catch {
                throw mapPostUnlinkSessionError(error)
            }
            return
        }

        let payload = try? JSONDecoder().decode(ProviderUnlinkErrorPayload.self, from: data)
        switch httpResponse.statusCode {
        case 403 where payload?.error == "account_disabled":
            throw AuthError.accountDisabled
        case 409 where payload?.error == "account_not_actionable":
            throw AuthError.accountNotActionable(reason: payload?.reason)
        case 502 where payload?.error == "firebase_admin_error":
            throw AuthError.firebaseAdminError(code: payload?.code)
        case 503 where payload?.error == "firebase_admin_not_configured":
            throw AuthError.firebaseAdminNotConfigured
        case 401:
            throw AuthError.invalidCredentials
        default:
            if let message = payload?.message, !message.isEmpty {
                throw AuthError.providerUnlinkFailed(message: message)
            }
            if let error = payload?.error, !error.isEmpty {
                throw AuthError.providerUnlinkFailed(message: error)
            }
            throw AuthError.providerUnlinkFailed(message: "Unable to update connected account. Please try again.")
        }
        #else
        throw AuthError.networkError
        #endif
    }

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

    func reload(user: FirebaseAuth.User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.reload { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
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

    func mapUnlinkSessionError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        if let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .userTokenExpired, .requiresRecentLogin, .userNotFound:
                return .sessionExpired
            default:
                break
            }
        }
        return .sessionExpired
    }

    func mapPostUnlinkSessionError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        if let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .userTokenExpired, .requiresRecentLogin, .userNotFound:
                return .providerDisconnectedRequiresSignIn
            default:
                break
            }
        }
        return .providerDisconnectedRequiresSignIn
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
    case sessionExpired
    case providerDisconnectedRequiresSignIn
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case userNotFound
    case wrongPassword
    case userDisabled
    case networkError
    case accountNotActionable(reason: String?)
    case accountDisabled
    case firebaseAdminError(code: String?)
    case firebaseAdminNotConfigured
    case providerUnlinkFailed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidCredentials:
            return "Invalid email or password"
        case .sessionExpired:
            return "Your sign-in session expired. Please sign in again."
        case .providerDisconnectedRequiresSignIn:
            return "Connected account updated. Please sign in again."
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
        case .accountNotActionable(let reason):
            switch reason {
            case "backend_user_missing":
                return "This account can't be updated right now. Please sign out and sign back in."
            case "account_deleted":
                return "This account has been deleted. Please sign in with another account."
            case "firebase_user_not_found":
                return "Sign-in state is out of sync. Please sign out and sign back in."
            default:
                return "This account can't be updated right now."
            }
        case .accountDisabled:
            return "This account is disabled."
        case .firebaseAdminError(let code):
            if let code, !code.isEmpty {
                return "Unable to update connected account (\(code)). Please try again."
            }
            return "Unable to update connected account. Please try again."
        case .firebaseAdminNotConfigured:
            return "Connected account updates are temporarily unavailable."
        case .providerUnlinkFailed(let message):
            return message
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

    // sha256/randomNonceString moved to AppleSignInUtilities
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
