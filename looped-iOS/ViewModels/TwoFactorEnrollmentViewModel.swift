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
    @Published var selectedCountry: CountryCallingCode = .defaultSelection
    @Published var phoneDigits = ""
    @Published var verificationCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var verificationID: String?

    var isPhoneNumberComplete: Bool {
        if selectedCountry.callingCode == "1" {
            return phoneDigits.count == 10
        }
        return (6...15).contains(phoneDigits.count)
    }

    func sendCode() async {
        guard let e164 = PhoneNumberFormatter.e164(digits: phoneDigits, countryCallingCode: selectedCountry.callingCode) else {
            errorMessage = "Enter a valid phone number."
            return
        }
        guard let user = Auth.auth().currentUser else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await user.multiFactor.session()
            let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(
                e164,
                uiDelegate: nil,
                multiFactorSession: session
            )
            verificationID = id
            step = .codeEntry
        } catch {
            let description = error.localizedDescription
            if description.localizedCaseInsensitiveContains("canHandleNotification") {
                errorMessage = "We couldn’t send a verification code right now. Please try again."
            } else {
                errorMessage = description
            }
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
    @Published var selectedCountry: CountryCallingCode = .defaultSelection
    @Published var phoneDigits = ""
    @Published var verificationCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var verificationID: String?

    var isPhoneNumberComplete: Bool { false }
    func sendCode() async {}
    func enroll() async -> Bool { false }
    func resendCode() async {}
}
#endif
