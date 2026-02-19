import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct CommunityEmailVerificationViewModelTests {
    @Test
    func loadDomains_reportsVerificationStepBeforeFetchingDomains() async {
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()
        let tracker = AsyncCallTracker()

        communityService.fetchCommunityDomainsHandler = { communityId in
            #expect(communityId == 123)
            #expect(tracker.callCount == 1)
            return ["wellsfargo.com"]
        }

        let viewModel = CommunityEmailVerificationViewModel(
            communityId: 123,
            communityName: "Wells Fargo",
            communityService: communityService,
            verificationService: verificationService,
            ensureOnboardingVerificationStep: {
                tracker.callCount += 1
            }
        )

        await viewModel.loadDomains()

        #expect(tracker.callCount == 1)
        #expect(communityService.fetchCommunityDomainsCalls == [123])
        #expect(viewModel.domains == ["wellsfargo.com"])
        #expect(viewModel.selectedDomain == "wellsfargo.com")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func sendCode_reportsVerificationStepBeforeStartingVerification() async {
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()
        let tracker = AsyncCallTracker()

        verificationService.startVerificationHandler = { communityId, method, email in
            #expect(communityId == 321)
            #expect(method == .email)
            #expect(email == "hello@wellsfargo.com")
            #expect(tracker.callCount == 1)
            return CommunityVerificationStartResponse(
                status: "pending",
                method: .email,
                devCode: nil,
                sessionId: nil,
                instructions: nil
            )
        }

        let viewModel = CommunityEmailVerificationViewModel(
            communityId: 321,
            communityName: "Wells Fargo",
            communityService: communityService,
            verificationService: verificationService,
            ensureOnboardingVerificationStep: {
                tracker.callCount += 1
            }
        )
        viewModel.emailLocalPart = "hello"
        viewModel.selectedDomain = "wellsfargo.com"

        let success = await viewModel.sendCode()

        #expect(success)
        #expect(tracker.callCount == 1)
        #expect(verificationService.startVerificationCalls.count == 1)
        #expect(viewModel.stage == .enterCode)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func sendCode_success_startsResendCooldownWithoutBlockingCodeSubmit() async {
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()

        verificationService.startVerificationHandler = { _, _, _ in
            CommunityVerificationStartResponse(
                status: "pending",
                method: .email,
                devCode: nil,
                sessionId: nil,
                instructions: nil
            )
        }

        let viewModel = CommunityEmailVerificationViewModel(
            communityId: 321,
            communityName: "Wells Fargo",
            communityService: communityService,
            verificationService: verificationService,
            defaultResendCooldownSeconds: 5
        )
        viewModel.emailLocalPart = "hello"
        viewModel.selectedDomain = "wellsfargo.com"

        let success = await viewModel.sendCode()

        #expect(success)
        #expect(viewModel.retryAfterSecondsRemaining == 5)
        #expect(viewModel.statusMessage == "Try again in 5s.")

        viewModel.code = "123456"
        #expect(viewModel.canSubmitCode)
    }

    @Test
    func sendCode_onboardingGateError_showsCleanRetryMessage() async {
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()

        verificationService.startVerificationHandler = { _, _, _ in
            throw APIError.apiError(
                code: 409,
                error: "onboarding_incomplete",
                message: "Complete onboarding before using this endpoint"
            )
        }

        let viewModel = CommunityEmailVerificationViewModel(
            communityId: 321,
            communityName: "Wells Fargo",
            communityService: communityService,
            verificationService: verificationService
        )
        viewModel.emailLocalPart = "hello"
        viewModel.selectedDomain = "wellsfargo.com"

        let success = await viewModel.sendCode()

        #expect(!success)
        #expect(viewModel.errorMessage == "Verification setup isn't ready yet. Please try again.")
    }

    @Test
    func loadDomains_onboardingSyncError_retriesAndLoadsDomains() async {
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()
        let tracker = AsyncCallTracker()
        var attempt = 0

        communityService.fetchCommunityDomainsHandler = { communityId in
            #expect(communityId == 555)
            attempt += 1
            if attempt == 1 {
                throw APIError.apiError(
                    code: 409,
                    error: "onboarding_incomplete",
                    message: "Complete onboarding before using this endpoint"
                )
            }
            return ["wellsfargo.com"]
        }

        let viewModel = CommunityEmailVerificationViewModel(
            communityId: 555,
            communityName: "Wells Fargo",
            communityService: communityService,
            verificationService: verificationService,
            ensureOnboardingVerificationStep: {
                tracker.callCount += 1
            },
            onboardingSyncRetryDelayNanoseconds: 0
        )

        await viewModel.loadDomains()

        #expect(tracker.callCount == 2)
        #expect(communityService.fetchCommunityDomainsCalls == [555, 555])
        #expect(viewModel.domains == ["wellsfargo.com"])
        #expect(viewModel.selectedDomain == "wellsfargo.com")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadDomains_onboardingSyncError_afterRetryFailure_showsCleanRetryMessage() async {
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()
        let tracker = AsyncCallTracker()

        communityService.fetchCommunityDomainsHandler = { communityId in
            #expect(communityId == 999)
            throw APIError.apiError(
                code: 409,
                error: "onboarding_incomplete",
                message: "Complete onboarding before using this endpoint"
            )
        }

        let viewModel = CommunityEmailVerificationViewModel(
            communityId: 999,
            communityName: "Wells Fargo",
            communityService: communityService,
            verificationService: verificationService,
            ensureOnboardingVerificationStep: {
                tracker.callCount += 1
            },
            onboardingSyncRetryDelayNanoseconds: 0
        )

        await viewModel.loadDomains()

        #expect(tracker.callCount == 2)
        #expect(communityService.fetchCommunityDomainsCalls == [999, 999])
        #expect(viewModel.errorMessage == "We couldn't load your company email domains yet. Tap Retry.")
    }

    @Test
    func sendCode_rateLimited_setsCooldownAndDisablesResend() async {
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()

        verificationService.startVerificationHandler = { _, _, _ in
            throw APIError.rateLimited(
                code: 429,
                error: "resend_cooldown",
                message: nil,
                retryAfterSeconds: 42
            )
        }

        let viewModel = CommunityEmailVerificationViewModel(
            communityId: 321,
            communityName: "Wells Fargo",
            communityService: communityService,
            verificationService: verificationService
        )
        viewModel.emailLocalPart = "hello"
        viewModel.selectedDomain = "wellsfargo.com"

        let success = await viewModel.sendCode()

        #expect(!success)
        #expect(viewModel.retryAfterSecondsRemaining == 42)
        #expect(!viewModel.canSendCode)
        #expect(viewModel.errorMessage == "Please wait 42s before requesting another code.")
        #expect(viewModel.statusMessage == "Try again in 42s.")
    }

    @Test
    func submitCode_tooManyAttempts_resetsToEmailEntryAndShowsFreshStartMessage() async {
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()

        verificationService.startVerificationHandler = { _, _, _ in
            CommunityVerificationStartResponse(
                status: "pending",
                method: .email,
                devCode: nil,
                sessionId: nil,
                instructions: nil
            )
        }
        verificationService.finishVerificationHandler = { _, _ in
            throw APIError.rateLimited(
                code: 429,
                error: "too_many_attempts",
                message: nil,
                retryAfterSeconds: 60
            )
        }

        let viewModel = CommunityEmailVerificationViewModel(
            communityId: 654,
            communityName: "Wells Fargo",
            communityService: communityService,
            verificationService: verificationService
        )
        viewModel.emailLocalPart = "hello"
        viewModel.selectedDomain = "wellsfargo.com"

        _ = await viewModel.sendCode()
        viewModel.code = "123456"

        let success = await viewModel.submitCode()

        #expect(!success)
        #expect(viewModel.stage == .enterEmail)
        #expect(viewModel.errorMessage == "Too many incorrect code attempts. Request a new code in 60s.")
        #expect(viewModel.retryAfterSecondsRemaining == 60)
        #expect(viewModel.statusMessage == "Try again in 60s.")
    }

    @Test
    func submitCode_usesExactEmailFromStartEvenIfDraftChanges() async {
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()
        var capturedEmail: String?

        verificationService.startVerificationHandler = { _, _, _ in
            CommunityVerificationStartResponse(
                status: "pending",
                method: .email,
                devCode: nil,
                sessionId: nil,
                instructions: nil
            )
        }
        verificationService.finishVerificationHandler = { _, request in
            capturedEmail = request.email
            return CommunityVerificationFinishResponse(
                verified: true,
                status: "approved",
                expiresAt: nil
            )
        }

        let viewModel = CommunityEmailVerificationViewModel(
            communityId: 777,
            communityName: "Wells Fargo",
            communityService: communityService,
            verificationService: verificationService
        )
        viewModel.emailLocalPart = "first"
        viewModel.selectedDomain = "wellsfargo.com"
        _ = await viewModel.sendCode()

        viewModel.emailLocalPart = "different"
        viewModel.selectedDomain = "another.com"
        viewModel.code = "123456"

        let success = await viewModel.submitCode()

        #expect(success)
        #expect(capturedEmail == "first@wellsfargo.com")
    }
}

private final class AsyncCallTracker {
    var callCount = 0
}
