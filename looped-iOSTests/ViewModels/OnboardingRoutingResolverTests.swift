import Testing
@testable import looped_iOS

struct OnboardingRoutingResolverTests {
    @Test
    func resolveScreen_remoteSelectCompany_routesToVerificationInfo() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStep: .selectCompany,
            localStep: nil,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .verificationInfo)
    }

    @Test
    func resolveScreen_remoteSelectCompany_keepsSelectCompanyAfterInfoStep() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStep: .selectCompany,
            localStep: .selectCompany,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .selectCompany)
    }

    @Test
    func resolveScreen_localVerificationInfo_restoresVerificationInfo() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStep: nil,
            localStep: .verificationInfo,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .verificationInfo)
    }

    @Test
    func resolveScreen_remoteVerification_keepsVerificationRoute() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStep: .verification,
            localStep: .verificationInfo,
            isStudent: true,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .verificationIntro(isStudent: true))
    }
}
