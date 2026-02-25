import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct AuthViewModelTests {

    @Test
    func loadCurrentUser_onboardingComplete_fetchesHydratedCurrentUser() async {
        let authService = MockAuthService()
        let userService = MockUserService()
        let deviceService = MockDeviceService()
        let registrarDefaults = makeDefaults(prefix: "auth.registrar")
        let registrar = NotificationDeviceRegistrar(deviceService: deviceService, userDefaults: registrarDefaults)

        let identityUser = TestFixtures.userDTO(id: 1, handle: "identity", displayName: "Identity")
        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: true,
                onboardingStep: nil,
                user: identityUser
            )
        }
        userService.getCurrentUserHandler = {
            TestFixtures.user(backendId: 99, handle: "current", displayName: "Current")
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: registrar,
            notificationService: MockNotificationService()
        )

        await viewModel.loadCurrentUser()

        #expect(viewModel.onboardingComplete == true)
        #expect(viewModel.shouldEnterOnboardingFlow == false)
        #expect(viewModel.onboardingStep == nil)
        #expect(viewModel.currentUser?.backendId == 99)
        #expect(viewModel.errorMessage == nil)
        #expect(userService.getIdentityCallCount == 1)
        #expect(userService.getCurrentUserCallCount == 1)
    }

    @Test
    func loadCurrentUser_populatesOnboardingV2Metadata() async {
        let authService = MockAuthService()
        let userService = MockUserService()
        let context = makeOnboardingContext(
            selectedOrgKind: "school",
            verificationPath: "email",
            verificationStatus: "approved"
        )
        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: false,
                onboardingStep: .verification,
                user: TestFixtures.userDTO(id: 4),
                onboardingStageV2: "email_verification",
                onboardingContext: context
            )
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.loadCurrentUser()

        #expect(viewModel.onboardingStageV2 == "email_verification")
        #expect(viewModel.onboardingContextV2 == context)
        #expect(viewModel.shouldEnterOnboardingFlow == true)
    }

    @Test
    func setOnboardingV2VerificationChoice_success_updatesOnboardingState() async {
        let authService = MockAuthService()
        authService.isAuthenticated = true
        let userService = MockUserService()
        userService.setOnboardingV2VerificationChoiceHandler = { path in
            #expect(path == "email")
            return OnboardingStateV2DTO(
                onboardingComplete: false,
                onboardingStep: .verification,
                onboardingStageV2: "email_verification",
                onboardingContext: makeOnboardingContext(verificationPath: "email")
            )
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        let success = await viewModel.setOnboardingV2VerificationChoice(path: "email")

        #expect(success == true)
        #expect(userService.setOnboardingV2VerificationChoiceCalls == ["email"])
        #expect(viewModel.onboardingStep == .verification)
        #expect(viewModel.onboardingStageV2 == "email_verification")
        #expect(viewModel.onboardingContextV2?.verificationPath == "email")
    }

    @Test
    func completeOnboardingAfterCommunityRequest_success_callsDedicatedEndpoint() async {
        let authService = MockAuthService()
        authService.isAuthenticated = true
        let userService = MockUserService()
        userService.completeOnboardingV2AfterCommunityRequestHandler = {
            return OnboardingStateV2DTO(
                onboardingComplete: true,
                onboardingStep: .verificationNotifications,
                onboardingStageV2: "completed",
                onboardingContext: makeOnboardingContext(completionReason: "community_requested")
            )
        }
        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: true,
                onboardingStep: nil,
                user: TestFixtures.userDTO(id: 52)
            )
        }
        userService.getCurrentUserHandler = {
            TestFixtures.user(backendId: 52, handle: "requestdone", displayName: "Request Done")
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        let success = await viewModel.completeOnboardingAfterCommunityRequest()

        #expect(success == true)
        #expect(userService.completeOnboardingV2AfterCommunityRequestCallCount == 1)
        #expect(userService.setOnboardingV2VerificationChoiceCalls.isEmpty)
        #expect(userService.acknowledgeOnboardingV2SkipExplainerCallCount == 0)
        #expect(userService.finalizeOnboardingV2CallCount == 0)
    }

    @Test
    func completeOnboardingAfterCommunityRequest_whenEndpointFails_returnsFalse() async {
        let authService = MockAuthService()
        authService.isAuthenticated = true
        let userService = MockUserService()
        userService.completeOnboardingV2AfterCommunityRequestHandler = {
            throw TestError(message: "community_request_required")
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        let success = await viewModel.completeOnboardingAfterCommunityRequest()

        #expect(success == false)
        #expect(userService.completeOnboardingV2AfterCommunityRequestCallCount == 1)
        #expect(userService.acknowledgeOnboardingV2SkipExplainerCallCount == 0)
        #expect(userService.finalizeOnboardingV2CallCount == 0)
    }

    @Test
    func loadCurrentUser_userNotProvisioned_setsOnboardingFallbackState() async {
        let authService = MockAuthService()
        let userService = MockUserService()
        userService.getIdentityHandler = {
            throw UserServiceError.userNotProvisioned
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.loadCurrentUser()

        #expect(viewModel.shouldEnterOnboardingFlow == true)
        #expect(viewModel.onboardingComplete == false)
        #expect(viewModel.onboardingStep == .profileSetup)
        #expect(viewModel.isProvisioned == false)
        #expect(viewModel.currentUser == nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadCurrentUser_error_setsErrorMessage() async {
        let authService = MockAuthService()
        let userService = MockUserService()
        userService.getIdentityHandler = {
            throw TestError(message: "identity failed")
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.loadCurrentUser()

        #expect(viewModel.errorMessage == "identity failed")
    }

    @Test
    func login_success_loadsIdentityAndClearsLoading() async {
        let authService = MockAuthService()
        authService.loginHandler = { _, _ in }

        let userService = MockUserService()
        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: false,
                onboardingStep: .verification,
                user: TestFixtures.userDTO(id: 12)
            )
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.login(email: "person@example.com", password: "pw")

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.currentUser?.backendId == 12)
        #expect(viewModel.onboardingStep == .verification)
        #expect(viewModel.shouldEnterOnboardingFlow == true)
        #expect(authService.loginCalls.count == 1)
        #expect(userService.getIdentityCallCount == 1)
    }

    @Test
    func login_failure_setsErrorAndSkipsIdentityFetch() async {
        let authService = MockAuthService()
        authService.loginHandler = { _, _ in
            throw TestError(message: "bad credentials")
        }

        let userService = MockUserService()

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.login(email: "person@example.com", password: "bad")

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == "bad credentials")
        #expect(userService.getIdentityCallCount == 0)
    }

    @Test
    func reportOnboardingStep_unauthenticated_doesNothing() async {
        let authService = MockAuthService()
        authService.isAuthenticated = false

        let userService = MockUserService()

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.reportOnboardingStep(.verification)

        #expect(userService.updateOnboardingStepCalls.isEmpty)
    }

    @Test
    func authStateChange_toAuthenticated_bootstrapsIdentity() async {
        let authService = MockAuthService()
        authService.isAuthenticated = false

        let userService = MockUserService()
        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: false,
                onboardingStep: .verification,
                user: TestFixtures.userDTO(id: 31)
            )
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        authService.emitAuthState(true)
        await waitFor {
            viewModel.didLoadIdentity == true && userService.getIdentityCallCount == 1
        }

        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.currentUser?.backendId == 31)
        #expect(viewModel.onboardingStep == .verification)
    }

    @Test
    func authStateChange_toUnauthenticated_resetsAuthState() async {
        let authService = MockAuthService()
        authService.isAuthenticated = true

        let userService = MockUserService()
        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: true,
                onboardingStep: nil,
                user: TestFixtures.userDTO(id: 77)
            )
        }
        userService.getCurrentUserHandler = {
            TestFixtures.user(backendId: 77)
        }
        await viewModel.loadCurrentUser()
        #expect(viewModel.isProvisioned == true)

        authService.emitAuthState(false)
        await waitFor { viewModel.didLoadIdentity == true && viewModel.isAuthenticated == false }

        #expect(viewModel.currentUser == nil)
        #expect(viewModel.onboardingComplete == false)
        #expect(viewModel.onboardingStep == nil)
        #expect(viewModel.isProvisioned == false)
        #expect(viewModel.shouldEnterOnboardingFlow == true)
    }

    @Test
    func loadCurrentUser_profileCompletionPayload_updatesPromptState() async {
        let authService = MockAuthService()
        authService.isAuthenticated = true
        let userService = MockUserService()
        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: true,
                onboardingStep: nil,
                user: TestFixtures.userDTO(id: 88),
                profileCompletion: ProfileCompletionDTO(
                    shouldPrompt: true,
                    missingPhoto: true,
                    missingBio: false,
                    missingSpecialization: true,
                    dismissedAt: nil,
                    completedAt: nil
                )
            )
        }
        userService.getCurrentUserHandler = {
            TestFixtures.user(backendId: 88, handle: "profile88", displayName: "Profile 88")
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.loadCurrentUser()

        #expect(viewModel.profileCompletionStatus?.shouldPrompt == true)
        #expect(viewModel.profileCompletionStatus?.missingPhoto == true)
        #expect(viewModel.profileCompletionStatus?.missingBio == false)
        #expect(viewModel.profileCompletionStatus?.missingSpecialization == true)
        #expect(viewModel.shouldPromptProfileCompletion == true)
    }

    @Test
    func dismissProfileCompletionPrompt_success_updatesLocalPromptState() async {
        let authService = MockAuthService()
        authService.isAuthenticated = true
        let userService = MockUserService()
        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: true,
                onboardingStep: nil,
                user: TestFixtures.userDTO(id: 111),
                profileCompletion: ProfileCompletionDTO(
                    shouldPrompt: true,
                    missingPhoto: true,
                    missingBio: true,
                    missingSpecialization: false,
                    dismissedAt: nil,
                    completedAt: nil
                )
            )
        }
        userService.getCurrentUserHandler = {
            TestFixtures.user(backendId: 111, handle: "ready", displayName: "Ready")
        }
        let dismissedAt = Date(timeIntervalSince1970: 1_700_123_456)
        userService.dismissProfileCompletionPromptHandler = {
            ProfileCompletionDTO(
                shouldPrompt: false,
                missingPhoto: true,
                missingBio: true,
                missingSpecialization: false,
                dismissedAt: dismissedAt,
                completedAt: nil
            )
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.loadCurrentUser()
        let dismissed = await viewModel.dismissProfileCompletionPrompt()

        #expect(dismissed == true)
        #expect(userService.dismissProfileCompletionPromptCallCount == 1)
        #expect(viewModel.profileCompletionStatus?.shouldPrompt == false)
        #expect(viewModel.profileCompletionStatus?.dismissedAt == dismissedAt)
        #expect(viewModel.shouldPromptProfileCompletion == false)
    }

    @Test
    func dismissProfileCompletionPrompt_successWithoutPayload_usesLocalFallbackState() async {
        let authService = MockAuthService()
        authService.isAuthenticated = true
        let userService = MockUserService()
        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: true,
                onboardingStep: nil,
                user: TestFixtures.userDTO(id: 113),
                profileCompletion: ProfileCompletionDTO(
                    shouldPrompt: true,
                    missingPhoto: false,
                    missingBio: true,
                    missingSpecialization: false,
                    dismissedAt: nil,
                    completedAt: nil
                )
            )
        }
        userService.getCurrentUserHandler = {
            TestFixtures.user(backendId: 113, handle: "localfallback", displayName: "Fallback")
        }
        userService.dismissProfileCompletionPromptHandler = {
            nil
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.loadCurrentUser()
        let dismissed = await viewModel.dismissProfileCompletionPrompt()

        #expect(dismissed == true)
        #expect(viewModel.profileCompletionStatus?.shouldPrompt == false)
        #expect(viewModel.profileCompletionStatus?.dismissedAt != nil)
    }

    @Test
    func dismissProfileCompletionPrompt_failure_keepsPromptAndSetsError() async {
        let authService = MockAuthService()
        authService.isAuthenticated = true
        let userService = MockUserService()
        userService.getIdentityHandler = {
            TestFixtures.identityDTO(
                provisioned: true,
                onboardingComplete: true,
                onboardingStep: nil,
                user: TestFixtures.userDTO(id: 112),
                profileCompletion: ProfileCompletionDTO(
                    shouldPrompt: true,
                    missingPhoto: false,
                    missingBio: true,
                    missingSpecialization: true,
                    dismissedAt: nil,
                    completedAt: nil
                )
            )
        }
        userService.getCurrentUserHandler = {
            TestFixtures.user(backendId: 112, handle: "pending", displayName: "Pending")
        }
        userService.dismissProfileCompletionPromptHandler = {
            throw TestError(message: "dismiss failed")
        }

        let viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            deviceRegistrar: NotificationDeviceRegistrar(deviceService: MockDeviceService(), userDefaults: makeDefaults(prefix: "auth.registrar")),
            notificationService: MockNotificationService()
        )

        await viewModel.loadCurrentUser()
        let dismissed = await viewModel.dismissProfileCompletionPrompt()

        #expect(dismissed == false)
        #expect(userService.dismissProfileCompletionPromptCallCount == 1)
        #expect(viewModel.profileCompletionStatus?.shouldPrompt == true)
        #expect(viewModel.shouldPromptProfileCompletion == true)
        #expect(viewModel.errorMessage == "dismiss failed")
    }
}

private func makeOnboardingContext(
    selectedOrgKind: String? = nil,
    verificationPath: String? = nil,
    verificationStatus: String? = nil,
    completionReason: String? = nil
) -> OnboardingContextV2DTO {
    OnboardingContextV2DTO(
        selectedOrgId: nil,
        selectedOrgName: nil,
        selectedOrgKind: selectedOrgKind,
        verificationPath: verificationPath,
        verificationStatus: verificationStatus,
        specializationRequired: nil,
        specializationId: nil,
        specializationName: nil,
        completionReason: completionReason
    )
}

private func makeDefaults(prefix: String) -> UserDefaults {
    let suite = "looped.tests.\(prefix).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@MainActor
private func waitFor(
    timeout: TimeInterval = 2.0,
    condition: @escaping @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}
