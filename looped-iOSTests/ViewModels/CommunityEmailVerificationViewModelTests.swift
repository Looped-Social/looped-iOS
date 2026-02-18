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
    func sendCode_onboardingGateError_showsSyncMessage() async {
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
        #expect(viewModel.errorMessage == "Your onboarding progress is still syncing. Try again in a moment.")
    }
}

private final class AsyncCallTracker {
    var callCount = 0
}
