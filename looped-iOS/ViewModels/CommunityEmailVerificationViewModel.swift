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
    @Published var debugMessage: String?

    private let communityService: CommunityServiceProtocol
    private let verificationService: CommunityVerificationServiceProtocol

    init(
        communityId: Int?,
        communityName: String,
        communityService: CommunityServiceProtocol = CommunityService(),
        verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()
    ) {
        self.communityId = communityId
        self.communityName = communityName
        self.communityService = communityService
        self.verificationService = verificationService
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
        resetDebug()
        appendDebug("start request: communityId=\(communityId), email=\(email)")
        do {
            let response = try await verificationService.startVerification(
                communityId: communityId,
                method: .email,
                email: email
            )
            stage = .enterCode
            code = ""
            statusMessage = "Verification code sent to \(email)."
            appendDebug(debugStartResponse(response))
            return true
        } catch {
            errorMessage = mapError(error)
            appendDebug(debugApiError(error, prefix: "start"))
            return false
        }
    }

    func resendCode() async {
        statusMessage = nil
        resetDebug()
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
        resetDebug()
        appendDebug("finish request: communityId=\(communityId), code=\(trimmedCode)")
        do {
            let response = try await verificationService.finishVerification(
                communityId: communityId,
                request: CommunityVerificationFinishRequest(
                    method: .email,
                    code: trimmedCode,
                    mediaKey: nil,
                    token: nil
                )
            )
            appendDebug("finish response: status=\(response.status), verified=\(response.verified)")
            return true
        } catch {
            errorMessage = mapError(error)
            appendDebug(debugApiError(error, prefix: "finish"))
            return false
        }
    }

    func resetToEmailEntry() {
        stage = .enterEmail
        code = ""
        errorMessage = nil
        statusMessage = nil
        resetDebug()
    }

    private var trimmedLocalPart: String {
        emailLocalPart.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func mapError(_ error: Error) -> String {
        if case let APIError.apiError(_, apiError, message) = error {
            switch apiError {
            case "email_send_failed":
                return "We couldn't send the email. Try again in a moment."
            case "invalid_code":
                return "That code looks wrong. Try again."
            case "invalid_email":
                return "Enter a valid email address."
            case "domain_not_allowed":
                return "Use your \(selectedDomain) email to verify."
            case "verification_not_supported":
                return "Email verification isn't available for this community."
            case "email_in_use":
                return "That email is already verified for this community. Unverify it in Settings → Community verifications, or use a different email."
            default:
                if let message, !message.isEmpty {
                    return message
                }
                return apiError
            }
        }
        return error.localizedDescription
    }

    private func debugStartResponse(_ response: CommunityVerificationStartResponse) -> String {
        let parts: [String] = [
            "start response",
            "status=\(response.status)",
            response.method.map { "method=\($0.rawValue)" } ?? nil,
            response.sessionId.map { "session=\($0)" } ?? nil,
            response.devCode.map { "devCode=\($0)" } ?? nil,
            response.instructions.map { "instructions=\($0)" } ?? nil
        ].compactMap { $0 }
        return parts.joined(separator: " • ")
    }

    private func debugApiError(_ error: Error, prefix: String) -> String {
        guard case let APIError.apiError(code, apiError, message) = error else {
            return "\(prefix) error: \(error.localizedDescription)"
        }
        if let message, !message.isEmpty {
            return "\(prefix) error: \(code) \(apiError) (\(message))"
        }
        return "\(prefix) error: \(code) \(apiError)"
    }

    private func resetDebug() {
        debugMessage = nil
    }

    private func appendDebug(_ line: String) {
        if let debugMessage, !debugMessage.isEmpty {
            self.debugMessage = debugMessage + "\n" + line
        } else {
            debugMessage = line
        }
    }
}
