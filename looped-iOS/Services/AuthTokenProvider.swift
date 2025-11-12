import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

protocol AuthTokenProvider {
    func currentIDToken() async throws -> String?
}

/// Firebase-backed ID token provider. Returns the current Firebase ID token
/// for the signed-in user. If no user is signed in, returns nil.
final class FirebaseAuthTokenProvider: AuthTokenProvider {
    func currentIDToken() async throws -> String? {
        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            return try await withCheckedThrowingContinuation { continuation in
                user.getIDTokenForcingRefresh(false) { token, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: token)
                }
            }
        } else {
            return nil
        }
        #else
        return nil
        #endif
    }
}

