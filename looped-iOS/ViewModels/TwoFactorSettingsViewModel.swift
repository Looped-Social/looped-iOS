import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct PhoneMFAFactor: Identifiable, Equatable {
    let id: String
    let displayName: String
    let phoneNumber: String
}

#if canImport(FirebaseAuth)
@MainActor
final class TwoFactorSettingsViewModel: ObservableObject {
    @Published var phoneFactors: [PhoneMFAFactor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var requiresReauth = false
    @Published var canReauthWithPassword = false
    @Published var pendingRemoval: PhoneMFAFactor?

    var isEnabled: Bool {
        !phoneFactors.isEmpty
    }

    func loadFactors() async {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let providers = user.providerData.map { $0.providerID }
        canReauthWithPassword = providers.contains("password")

	        let factors = user.multiFactor.enrolledFactors.compactMap { info -> PhoneMFAFactor? in
	            guard let phone = info as? PhoneMultiFactorInfo else { return nil }
	            let rawName = phone.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
	            let name = rawName.isEmpty ? "Phone" : rawName
	            return PhoneMFAFactor(id: phone.uid, displayName: name, phoneNumber: phone.phoneNumber)
	        }
		        phoneFactors = factors
		        #endif
		    }

    func requestRemove(_ factor: PhoneMFAFactor) async {
        pendingRemoval = factor
        await removePendingFactor()
    }

    func removePendingFactor() async {
        #if canImport(FirebaseAuth)
        guard let factor = pendingRemoval else { return }
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await unenroll(user: user, factorId: factor.id)
            pendingRemoval = nil
            await loadFactors()
        } catch {
            if isRequiresRecentLogin(error) {
                requiresReauth = true
                return
            }
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func reauthenticateWithPassword(_ password: String) async -> Bool {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser, let email = user.email else {
            errorMessage = "Missing account email."
            return false
        }

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await reauthenticate(user: user, credential: credential)
            requiresReauth = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        #else
        return false
        #endif
    }

    private func isRequiresRecentLogin(_ error: Error) -> Bool {
        let nsError = error as NSError
        if let code = AuthErrorCode(rawValue: nsError.code) {
            return code == .requiresRecentLogin
        }
        return false
    }

    private func reauthenticate(user: FirebaseAuth.User, credential: AuthCredential) async throws {
        _ = try await user.reauthenticate(with: credential)
    }

    private func unenroll(user: FirebaseAuth.User, factorId: String) async throws {
        try await user.multiFactor.unenroll(withFactorUID: factorId)
    }
}
#else
@MainActor
final class TwoFactorSettingsViewModel: ObservableObject {
    @Published var phoneFactors: [PhoneMFAFactor] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var requiresReauth = false
    @Published var canReauthWithPassword = false
    @Published var pendingRemoval: PhoneMFAFactor?

    var isEnabled: Bool { false }

    func loadFactors() async {}
    func requestRemove(_ factor: PhoneMFAFactor) async {}
    func removePendingFactor() async {}
    func reauthenticateWithPassword(_ password: String) async -> Bool { false }
}
#endif
