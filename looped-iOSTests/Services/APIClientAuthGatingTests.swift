import Testing
@testable import looped_iOS

@Suite
struct APIClientAuthGatingTests {
    @Test
    func invalidOnboardingStage422_isAuthGatingError() {
        let error = APIError.apiError(code: 422, error: "invalid_onboarding_stage", message: nil)

        #expect(error.isAuthGatingError == true)
        #expect(error.authGatingContext?.code == .invalidOnboardingStage)
    }

    @Test
    func invalidOnboardingStageNon422_isNotAuthGatingError() {
        let error = APIError.apiError(code: 409, error: "invalid_onboarding_stage", message: nil)

        #expect(error.isAuthGatingError == false)
        #expect(error.authGatingContext == nil)
    }
}
