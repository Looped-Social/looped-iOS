import Testing
@testable import looped_iOS

struct OnboardingRoutingResolverTests {
    @Test
    func resolveScreen_remoteInfoScreen_routesToVerificationInfo() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: "info_screen",
            remoteContext: nil,
            remoteStep: .selectCompany,
            localStep: nil,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .verificationInfo)
    }

    @Test
    func resolveScreen_remoteVerificationChoice_forSchool_routesToStudentWays() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: "verification_choice",
            remoteContext: makeContext(selectedOrgKind: "school"),
            remoteStep: .verification,
            localStep: nil,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .waysToVerifyStudent)
    }

    @Test
    func resolveScreen_orgSelection_holdsOnInfoUntilAcknowledgedLocally() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: "org_selection",
            remoteContext: nil,
            remoteStep: .selectCompany,
            localStep: .verificationInfo,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .verificationInfo)
    }

    @Test
    func resolveScreen_orgSelected_withSelectedOrg_routesToVerificationIntro() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: "org_selected",
            remoteContext: makeContext(selectedOrgKind: "school", selectedOrgId: 42),
            remoteStep: .verification,
            localStep: .selectCompany,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .verificationIntro(isStudent: true))
    }

    @Test
    func resolveScreen_orgSelected_withAllowedNext_usesAllowedFallback() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: "org_selected",
            remoteContext: makeContext(selectedOrgKind: "company", selectedOrgId: 42),
            allowedNextStagesV2: ["verification_choice"],
            remoteStep: .verification,
            localStep: .selectCompany,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .waysToVerifyCompany)
    }

    @Test
    func resolveScreen_localSpecialization_withoutRemoteState_fallsBackToOrgSelection() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: nil,
            remoteContext: nil,
            remoteStep: nil,
            localStep: .degreeSelection,
            isStudent: true,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .selectCompany)
    }

    @Test
    func resolveScreen_emailApprovedWithoutSpecialization_routesToSpecializationPicker() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: nil,
            remoteContext: makeContext(
                selectedOrgKind: "company",
                verificationPath: "email",
                verificationStatus: "approved",
                specializationRequired: true,
                specializationId: nil
            ),
            remoteStep: nil,
            localStep: nil,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .departmentSelection)
    }

    @Test
    func resolveScreen_emailStage_withAllowedSpecialization_staysOnEmailVerification() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: "email_verification",
            remoteContext: makeContext(selectedOrgKind: "school"),
            allowedNextStagesV2: ["specialization_selection"],
            remoteStep: .verification,
            localStep: nil,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .emailVerification(isStudent: true))
    }

    @Test
    func resolveScreen_specializationSelection_withAllowedCompleted_routesToConfirmation() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: "specialization_selection",
            remoteContext: makeContext(selectedOrgKind: "school"),
            allowedNextStagesV2: ["completed"],
            remoteStep: .verification,
            localStep: .degreeSelection,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .verificationConfirmation)
    }

    @Test
    func resolveScreen_unknownStage_usesAllowedNextFallback() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: "unexpected_stage",
            remoteContext: makeContext(selectedOrgKind: "company"),
            allowedNextStagesV2: ["skip_explainer"],
            remoteStep: .verification,
            localStep: nil,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .skipVerificationExplainer)
    }

    @Test
    func resolveScreen_emailWithSpecialization_routesToConfirmation() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: nil,
            remoteContext: makeContext(
                selectedOrgKind: "school",
                verificationPath: "email",
                verificationStatus: "approved",
                specializationRequired: true,
                specializationId: 42
            ),
            remoteStep: nil,
            localStep: nil,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .verificationConfirmation)
    }

    @Test
    func resolveScreen_skipPath_routesToSkipExplainer() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: nil,
            remoteContext: makeContext(verificationPath: "skip"),
            remoteStep: nil,
            localStep: nil,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .skipVerificationExplainer)
    }

    @Test
    func resolveScreen_photoPending_routesToPendingExplainer() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: nil,
            remoteContext: makeContext(
                verificationPath: "photo_id",
                verificationStatus: "pending"
            ),
            remoteStep: nil,
            localStep: nil,
            isStudent: false,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .photoPendingExplainer)
    }

    @Test
    func resolveScreen_legacyFallback_remoteVerification_routesToVerificationIntro() {
        let resolved = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: nil,
            remoteContext: nil,
            remoteStep: .verification,
            localStep: nil,
            isStudent: true,
            shouldEnterOnboardingFlow: true
        )

        #expect(resolved == .verificationIntro(isStudent: true))
    }
}

private func makeContext(
    selectedOrgKind: String? = nil,
    selectedOrgId: Int? = nil,
    selectedOrgName: String? = nil,
    verificationPath: String? = nil,
    verificationStatus: String? = nil,
    specializationRequired: Bool? = nil,
    specializationId: Int? = nil
) -> OnboardingContextV2DTO {
    OnboardingContextV2DTO(
        selectedOrgId: selectedOrgId,
        selectedOrgName: selectedOrgName,
        selectedOrgKind: selectedOrgKind,
        verificationPath: verificationPath,
        verificationStatus: verificationStatus,
        specializationRequired: specializationRequired,
        specializationId: specializationId,
        specializationName: nil,
        completionReason: nil
    )
}
