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
    @Published private(set) var retryAfterSecondsRemaining = 0
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let communityService: CommunityServiceProtocol
    private let verificationService: CommunityVerificationServiceProtocol
    private let ensureOnboardingVerificationStep: (() async -> Void)?
    private let onboardingSyncRetryDelayNanoseconds: UInt64
    private let defaultResendCooldownSeconds: Int
    private var pendingEmail: String?
    private var retryCooldownTask: Task<Void, Never>?

    init(
        communityId: Int?,
        communityName: String,
        communityService: CommunityServiceProtocol = CommunityService(),
        verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService(),
        ensureOnboardingVerificationStep: (() async -> Void)? = nil,
        onboardingSyncRetryDelayNanoseconds: UInt64 = 250_000_000,
        defaultResendCooldownSeconds: Int = 30
    ) {
        self.communityId = communityId
        self.communityName = communityName
        self.communityService = communityService
        self.verificationService = verificationService
        self.ensureOnboardingVerificationStep = ensureOnboardingVerificationStep
        self.onboardingSyncRetryDelayNanoseconds = onboardingSyncRetryDelayNanoseconds
        self.defaultResendCooldownSeconds = defaultResendCooldownSeconds
    }

    deinit {
        retryCooldownTask?.cancel()
    }

    var canSendCode: Bool {
        !trimmedLocalPart.isEmpty
            && !selectedDomain.isEmpty
            && retryAfterSecondsRemaining == 0
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
            if isOnboardingSyncError(error) {
                if let ensureOnboardingVerificationStep {
                    await ensureOnboardingVerificationStep()
                }
                if onboardingSyncRetryDelayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: onboardingSyncRetryDelayNanoseconds)
                }
                do {
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
                    isFetchingDomains = false
                    return
                } catch {
                    errorMessage = mapDomainLoadError(error)
                }
            } else {
                errorMessage = mapDomainLoadError(error)
            }
        }
        isFetchingDomains = false
    }

    func sendCode() async -> Bool {
        guard let communityId else {
            errorMessage = "Missing community for verification."
            return false
        }
        guard retryAfterSecondsRemaining == 0 else {
            statusMessage = "Try again in \(retryAfterSecondsRemaining)s."
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
            let cooldownSeconds = max(defaultResendCooldownSeconds, 1)
            startRetryCooldown(seconds: cooldownSeconds)
            return true
        } catch {
            applyRateLimitIfNeeded(error)
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
        let email = pendingEmail
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
            clearRateLimitIfNeeded()
            LoopedHaptics.verificationSuccess()
            return true
        } catch {
            applyRateLimitIfNeeded(error)
            if requiresFreshStart(error) {
                let activeCooldownStatus = statusMessage
                resetToEmailEntry()
                if retryAfterSecondsRemaining > 0 {
                    statusMessage = activeCooldownStatus ?? "Try again in \(retryAfterSecondsRemaining)s."
                }
                errorMessage = mapError(error)
                return false
            }
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

    private func isOnboardingSyncError(_ error: Error) -> Bool {
        guard case let APIError.apiError(_, apiError, _) = error else { return false }
        return apiError == "onboarding_incomplete" || apiError == "invalid_onboarding_step"
    }

    private func applyRateLimitIfNeeded(_ error: Error) {
        guard let apiError = error as? APIError else { return }
        if let retryAfterSeconds = apiError.retryAfterSeconds {
            startRetryCooldown(seconds: retryAfterSeconds)
            return
        }

        guard let code = apiError.apiErrorCode else { return }
        let fallbackCodes = Set([
            "resend_cooldown",
            "email_start_rate_limited_hour",
            "email_start_rate_limited_day",
            "too_many_attempts"
        ])
        guard fallbackCodes.contains(code) else { return }
        startRetryCooldown(seconds: 30)
    }

    private func clearRateLimitIfNeeded() {
        retryCooldownTask?.cancel()
        retryCooldownTask = nil
        retryAfterSecondsRemaining = 0
        if statusMessage?.hasPrefix("Try again in ") == true {
            statusMessage = nil
        }
    }

    private func startRetryCooldown(seconds: Int) {
        let bounded = max(1, seconds)
        retryCooldownTask?.cancel()
        retryAfterSecondsRemaining = bounded
        statusMessage = "Try again in \(bounded)s."

        retryCooldownTask = Task { [weak self] in
            var remaining = bounded
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                remaining -= 1
                await MainActor.run {
                    guard let self else { return }
                    self.retryAfterSecondsRemaining = remaining
                    if remaining > 0 {
                        self.statusMessage = "Try again in \(remaining)s."
                    } else if self.statusMessage?.hasPrefix("Try again in ") == true {
                        self.statusMessage = nil
                    }
                }
            }
        }
    }

    private func requiresFreshStart(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        guard let code = apiError.apiErrorCode else { return false }
        return code == "too_many_attempts" || code == "email_mismatch"
    }

    private func mapDomainLoadError(_ error: Error) -> String {
        if isOnboardingSyncError(error) {
            return "We couldn't load your company email domains yet. Tap Retry."
        }
        return mapError(error)
    }

    private func mapError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            if case .rateLimited(_, let code, _, let retryAfterSeconds) = apiError {
                switch code {
                case "resend_cooldown":
                    if let retryAfterSeconds {
                        return "Please wait \(retryAfterSeconds)s before requesting another code."
                    }
                    return "Please wait before requesting another code."
                case "email_start_rate_limited_hour", "email_start_rate_limited_day":
                    if let retryAfterSeconds {
                        return "Too many code requests. Try again in \(retryAfterSeconds)s."
                    }
                    return "Too many code requests. Try again later."
                case "too_many_attempts":
                    if let retryAfterSeconds {
                        return "Too many incorrect code attempts. Request a new code in \(retryAfterSeconds)s."
                    }
                    return "Too many incorrect code attempts. Request a new code."
                default:
                    if let retryAfterSeconds {
                        return "Too many attempts. Try again in \(retryAfterSeconds)s."
                    }
                    return "Too many attempts. Try again later."
                }
            }

            if case let APIError.apiError(_, apiErrorCode, message) = apiError {
                switch apiErrorCode {
                case "too_many_attempts":
                    return "Too many incorrect code attempts. Request a new code."
                case "email_mismatch":
                    return "This code is tied to a different email. Request a new code."
                case "resend_cooldown", "email_start_rate_limited_hour", "email_start_rate_limited_day":
                    if let retryAfterSeconds = apiError.retryAfterSeconds {
                        return "Too many attempts. Try again in \(retryAfterSeconds)s."
                    }
                    return "Too many attempts. Try again later."
                case "community_not_found":
                    return "That community no longer exists."
                case "user_not_provisioned":
                    return "Finish setting up your account before verifying."
                case "onboarding_incomplete", "invalid_onboarding_step":
                    return "Verification setup isn't ready yet. Please try again."
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
                    return apiErrorCode
                }
            }
        }
        return error.localizedDescription
    }

    // Intentionally no user-facing debug output in production UI.
}
