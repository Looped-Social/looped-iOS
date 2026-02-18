import Foundation

@MainActor
final class CommunityEmailVerificationViewModel: ObservableObject {
    enum Stage {
        case enterEmail
        case enterCode
    }

    let communityId: Int?
    let communityName: String

    @Published var stage: Stage = .enterEmail
    @Published var emailLocalPart = ""
    @Published var domains: [String] = []
    @Published var selectedDomain = ""
    @Published var code = ""
    @Published var isFetchingDomains = false
    @Published var isSendingCode = false
    @Published var isVerifyingCode = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let communityService: CommunityServiceProtocol
    private let verificationService: CommunityVerificationServiceProtocol
    private let ensureOnboardingVerificationStep: (() async -> Void)?
    private var pendingEmail: String?

    init(
        communityId: Int?,
        communityName: String,
        communityService: CommunityServiceProtocol = CommunityService(),
        verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService(),
        ensureOnboardingVerificationStep: (() async -> Void)? = nil
    ) {
        self.communityId = communityId
        self.communityName = communityName
        self.communityService = communityService
        self.verificationService = verificationService
        self.ensureOnboardingVerificationStep = ensureOnboardingVerificationStep
    }

    var canSendCode: Bool {
        !trimmedLocalPart.isEmpty && !selectedDomain.isEmpty
    }

    var canSubmitCode: Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).count == 6
    }

    var composedEmail: String? {
        guard canSendCode else { return nil }
        return "\(trimmedLocalPart)@\(selectedDomain)"
    }

    func loadDomains() async {
        guard !isFetchingDomains else { return }
        guard let communityId else {
            errorMessage = "Missing community for verification."
            return
        }
        isFetchingDomains = true
        errorMessage = nil
        do {
            if let ensureOnboardingVerificationStep {
                await ensureOnboardingVerificationStep()
            }
            let items = try await communityService.fetchCommunityDomains(communityId: communityId)
            let normalized = items
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            domains = normalized
            if selectedDomain.isEmpty, let first = normalized.first {
                selectedDomain = first
            }
            if domains.isEmpty {
                errorMessage = "No email domains available for this community."
            }
        } catch {
            errorMessage = mapError(error)
        }
        isFetchingDomains = false
    }

    func sendCode() async -> Bool {
        guard let communityId else {
            errorMessage = "Missing community for verification."
            return false
        }
        guard let email = composedEmail else {
            errorMessage = "Enter your email to continue."
            return false
        }
        guard !isSendingCode else { return false }
        isSendingCode = true
        defer { isSendingCode = false }
        errorMessage = nil
        statusMessage = nil
        do {
            if let ensureOnboardingVerificationStep {
                await ensureOnboardingVerificationStep()
            }
            _ = try await verificationService.startVerification(
                communityId: communityId,
                method: .email,
                email: email
            )
            stage = .enterCode
            code = ""
            pendingEmail = email
            statusMessage = "Check your email. If you don’t see it, check spam."
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    func resendCode() async {
        statusMessage = nil
        _ = await sendCode()
    }

    func submitCode() async -> Bool {
        guard let communityId else {
            errorMessage = "Missing community for verification."
            return false
        }
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCode.count == 6 else {
            errorMessage = "Enter the 6-digit code."
            return false
        }
        guard !isVerifyingCode else { return false }
        isVerifyingCode = true
        defer { isVerifyingCode = false }
        errorMessage = nil
        statusMessage = nil
        let email = pendingEmail ?? composedEmail
        do {
            if let ensureOnboardingVerificationStep {
                await ensureOnboardingVerificationStep()
            }
            _ = try await verificationService.finishVerification(
                communityId: communityId,
                request: CommunityVerificationFinishRequest(
                    method: .email,
                    code: trimmedCode,
                    mediaKey: nil,
                    token: nil,
                    email: email
                )
            )
            NotificationCenter.default.post(
                name: .communityStateChanged,
                object: nil,
                userInfo: [LoopedNotificationUserInfoKey.communityId: communityId]
            )
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    func resetToEmailEntry() {
        stage = .enterEmail
        code = ""
        pendingEmail = nil
        errorMessage = nil
        statusMessage = nil
    }

    private var trimmedLocalPart: String {
        emailLocalPart.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func mapError(_ error: Error) -> String {
        if case let APIError.apiError(_, apiError, message) = error {
            switch apiError {
            case "community_not_found":
                return "That community no longer exists."
            case "user_not_provisioned":
                return "Finish setting up your account before verifying."
            case "onboarding_incomplete", "invalid_onboarding_step":
                return "Your onboarding progress is still syncing. Try again in a moment."
            case "email_send_failed":
                return "We couldn't send the email. Try again in a moment."
            case "email_required":
                return "Enter your email to continue."
            case "invalid_code":
                return "That code looks wrong. Try again."
            case "code_required":
                return "Enter the 6-digit code."
            case "invalid_email":
                return "Enter a valid email address."
            case "domains_not_configured":
                return "Email verification isn't configured for this community."
            case "email_domain_not_allowed", "domain_not_allowed":
                return "That email domain isn't allowed for this community."
            case "unsupported_method":
                return "That verification method isn't supported."
            case "verification_not_supported":
                return "Email verification isn't available for this community."
            case "email_in_use":
                return "That email is already actively verified for this community by another account. Use a different email, or unverify it from the verified account (Settings → Community verifications); it can also be used again after the verification expires."
            default:
                if let message, !message.isEmpty {
                    return message
                }
                return apiError
            }
        }
        return error.localizedDescription
    }

    // Intentionally no user-facing debug output in production UI.
}
