import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth

@MainActor
final class TwoFactorEnrollmentViewModel: ObservableObject {
    enum Step {
        case phoneEntry
        case codeEntry
        case success
    }

    @Published var step: Step = .phoneEntry
    @Published var phoneNumber = ""
    @Published var verificationCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var verificationID: String?

    func sendCode() async {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("+") else {
            errorMessage = "Use a phone number with country code (ex: +1 555 123 4567)."
            return
        }
        guard let user = Auth.auth().currentUser else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await user.multiFactor.session()
            let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(
                trimmed,
                uiDelegate: nil,
                multiFactorSession: session
            )
            verificationID = id
            step = .codeEntry
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func enroll() async -> Bool {
        guard let id = verificationID else { return false }
        let code = verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            errorMessage = "Enter the verification code."
            return false
        }
        guard let user = Auth.auth().currentUser else { return false }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: id, verificationCode: code)
            let assertion = PhoneMultiFactorGenerator.assertion(with: credential)
            try await user.multiFactor.enroll(with: assertion, displayName: "Phone")
            step = .success
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func resendCode() async {
        await sendCode()
    }

}

#else
@MainActor
final class TwoFactorEnrollmentViewModel: ObservableObject {
    enum Step {
        case phoneEntry
        case codeEntry
        case success
    }

    @Published var step: Step = .phoneEntry
    @Published var phoneNumber = ""
    @Published var verificationCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var verificationID: String?

    func sendCode() async {}
    func enroll() async -> Bool { false }
    func resendCode() async {}
}
#endif
