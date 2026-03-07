import SwiftUI
import Foundation

struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @State private var path: [AuthScreen] = []
    @State private var selectedLoopName: String = "Looped"
    @State private var selectedCommunityId: Int?
    @State private var companySearchText: String = ""
    @State private var organizationSearchTextLegacy: String = ""
    @State private var departmentSearchText: String = ""
    @State private var selectedDepartments: [CommunitySearchResult] = []
    @State private var companyVerificationOptionId: String?
    @State private var verificationContext: VerificationContext?
    private let onboardingStore = OnboardingProgressStore()
    @State private var verificationFlowMode: VerificationFlowMode = .full
    private let communityService: CommunityServiceProtocol = CommunityService()
    private let verificationInfoURL = URL(string: "https://looped-social.com/privacy")!
    private var uiTestStartOnLogin: Bool {
        ProcessInfo.processInfo.environment["LOOPED_UI_TEST_START_ON_LOGIN"] == "1"
    }
    private var shouldSuppressWelcomeScreen: Bool {
        authViewModel.isAuthenticated
            && !authViewModel.onboardingComplete
            && path.isEmpty
            && (!authViewModel.didLoadIdentity || authViewModel.isLoading)
    }

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingView(authViewModel: authViewModel) { screen in
                navigate(to: screen)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthScreen.self) { screen in
                destination(for: screen)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .loadingOverlay(isPresented: shouldSuppressWelcomeScreen, title: "Resuming onboarding…")
        #if canImport(FirebaseAuth)
        .sheet(item: $authViewModel.mfaSession) { session in
            TwoFactorChallengeView(authViewModel: authViewModel, session: session)
        }
        #endif
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthed in
            if isAuthed {
                restoreOnboardingScreen()
            }
        }
        .onChange(of: path) { _, newValue in
            let screen = newValue.last ?? .onboarding
            persistProgress(for: screen)
        }
        .onChange(of: authViewModel.onboardingStep) { _, _ in
            if authViewModel.isAuthenticated, !authViewModel.onboardingComplete {
                logOnboardingDebug("onboardingStep changed to \(authViewModel.onboardingStep?.rawValue ?? "nil")")
                restoreOnboardingScreen()
            }
        }
        .onChange(of: authViewModel.onboardingStageV2) { _, _ in
            if authViewModel.isAuthenticated, !authViewModel.onboardingComplete {
                logOnboardingDebug("onboardingStageV2 changed to \(authViewModel.onboardingStageV2 ?? "nil"), allowed=\(authViewModel.onboardingAllowedNextStagesV2)")
                restoreOnboardingScreen()
            }
        }
        .onChange(of: authViewModel.onboardingComplete) { _, newValue in
            if newValue {
                onboardingStore.clearAll()
            }
        }
        .onChange(of: authViewModel.didLoadIdentity) { _, didLoadIdentity in
            if didLoadIdentity, authViewModel.isAuthenticated, !authViewModel.onboardingComplete {
                restoreOnboardingScreen()
            }
        }
        .onAppear {
            if uiTestStartOnLogin, path.isEmpty {
                navigate(to: .login)
                return
            }
            if authViewModel.isAuthenticated {
                Task {
                    await authViewModel.loadCurrentUser()
                    restoreOnboardingScreen()
                }
            }
        }
    }
}

private extension AuthView {
    @ViewBuilder
    func destination(for screen: AuthScreen) -> some View {
        switch screen {
        case .onboarding:
            EmptyView()
                .onAppear { path.removeAll() }
        case .profileSetup:
            ProfileSetupView(
                authViewModel: authViewModel,
                onContinue: {
                    onboardingStore.saveProgress(.verificationInfo)
                    setNavigationStack(for: .verificationInfo)
                }
            )
        case .verificationInfo:
            VerificationInfoOnboardingView {
                Task {
                    let success = await authViewModel.markOnboardingInfoScreenViewed()
                    guard success else { return }
                    setNavigationStack(for: .selectCompany)
                }
            }
        case .selectCompany:
            OrganizationSelectionView(
                title: "Search for your workplace",
                scope: .companiesOnly,
                searchText: $companySearchText,
                selectedOrganizationId: authViewModel.selectedOrganization?.id,
                onSelect: { organization in
                    authViewModel.selectedOrganization = organization
                    selectedLoopName = organization.name
                    selectedCommunityId = organization.backendId
                    onboardingStore.saveOrganizationDraft(
                        OnboardingOrganizationDraft(
                            backendId: organization.backendId,
                            name: organization.name,
                            kind: organization.kind,
                            imageURL: organization.imageURL
                        )
                    )
                    if let id = organization.backendId {
                        UserDefaults.standard.set(id, forKey: "lastSelectedCommunityId")
                    } else {
                        UserDefaults.standard.removeObject(forKey: "lastSelectedCommunityId")
                    }
                },
                onContinue: { organization in
                    authViewModel.selectedOrganization = organization
                    selectedLoopName = organization.name
                    selectedCommunityId = organization.backendId
                    followCommunityIfPossible(organization.backendId)
                    guard let orgId = organization.backendId else {
                        logOnboardingDebug("org continue blocked: missing backendId for \(organization.name)")
                        return
                    }
                    logOnboardingDebug("org continue tapped: orgId=\(orgId), name=\(organization.name), stage=\(authViewModel.onboardingStageV2 ?? "nil"), local=\(onboardingStore.loadProgress()?.rawValue ?? "nil")")
                    Task {
                        let success = await authViewModel.setOnboardingV2Organization(orgId: orgId)
                        logOnboardingDebug("org set result: success=\(success), stage=\(authViewModel.onboardingStageV2 ?? "nil"), allowed=\(authViewModel.onboardingAllowedNextStagesV2)")
                        guard success else {
                            await authViewModel.loadCurrentUser()
                            logOnboardingDebug("org set failed; refreshed identity stage=\(authViewModel.onboardingStageV2 ?? "nil"), step=\(authViewModel.onboardingStep?.rawValue ?? "nil")")
                            restoreOnboardingScreen()
                            return
                        }
                        restoreOnboardingScreen()
                    }
                },
                onRequestCommunityCompletion: {
                    let success = await authViewModel.completeOnboardingAfterCommunityRequest()
                    if !success {
                        await authViewModel.loadCurrentUser()
                        restoreOnboardingScreen()
                    }
                    return success
                }
            )
        case .selectOrganizationLegacy:
            OrganizationSelectionView(
                title: "Search for your workplace",
                scope: .companiesOnly,
                searchText: $organizationSearchTextLegacy,
                selectedOrganizationId: authViewModel.selectedOrganization?.id,
                onSelect: { organization in
                    authViewModel.selectedOrganization = organization
                    selectedLoopName = organization.name
                    selectedCommunityId = organization.backendId
                    onboardingStore.saveOrganizationDraft(
                        OnboardingOrganizationDraft(
                            backendId: organization.backendId,
                            name: organization.name,
                            kind: organization.kind,
                            imageURL: organization.imageURL
                        )
                    )
                    if let id = organization.backendId {
                        UserDefaults.standard.set(id, forKey: "lastSelectedCommunityId")
                    } else {
                        UserDefaults.standard.removeObject(forKey: "lastSelectedCommunityId")
                    }
                },
                onContinue: { organization in
                    authViewModel.selectedOrganization = organization
                    selectedLoopName = organization.name
                    selectedCommunityId = organization.backendId
                    followCommunityIfPossible(organization.backendId)
                    guard let orgId = organization.backendId else {
                        logOnboardingDebug("org continue blocked: missing backendId for \(organization.name)")
                        return
                    }
                    logOnboardingDebug("org continue tapped: orgId=\(orgId), name=\(organization.name), stage=\(authViewModel.onboardingStageV2 ?? "nil"), local=\(onboardingStore.loadProgress()?.rawValue ?? "nil")")
                    Task {
                        let success = await authViewModel.setOnboardingV2Organization(orgId: orgId)
                        logOnboardingDebug("org set result: success=\(success), stage=\(authViewModel.onboardingStageV2 ?? "nil"), allowed=\(authViewModel.onboardingAllowedNextStagesV2)")
                        guard success else {
                            await authViewModel.loadCurrentUser()
                            logOnboardingDebug("org set failed; refreshed identity stage=\(authViewModel.onboardingStageV2 ?? "nil"), step=\(authViewModel.onboardingStep?.rawValue ?? "nil")")
                            restoreOnboardingScreen()
                            return
                        }
                        restoreOnboardingScreen()
                    }
                },
                onRequestCommunityCompletion: {
                    let success = await authViewModel.completeOnboardingAfterCommunityRequest()
                    if !success {
                        await authViewModel.loadCurrentUser()
                        restoreOnboardingScreen()
                    }
                    return success
                }
            )
        case .departmentSelection:
            OrganizationDetailSelectionView(
                title: "Field",
                kind: .field,
                searchText: $departmentSearchText,
                selectedItems: $selectedDepartments,
                maxSelections: 2,
                onSelect: { selections in
                    selectedDepartments = selections
                },
                onContinue: { selections in
                    Task {
                        await submitOnboardingSpecializations(selections)
                    }
                }
            )
        case .fieldSelectionLegacy:
            OrganizationDetailSelectionView(
                title: "Field",
                kind: .field,
                searchText: $departmentSearchText,
                selectedItems: $selectedDepartments,
                maxSelections: 2,
                onSelect: { selections in
                    selectedDepartments = selections
                },
                onContinue: { selections in
                    Task {
                        await submitOnboardingSpecializations(selections)
                    }
                }
            )
        case .verificationIntro(let isLegacyFlow):
            VerificationIntroView(
                loopName: selectedLoopName,
                currentStep: verificationStep(for: .verificationIntro(isLegacyFlow: isLegacyFlow)),
                totalSteps: verificationTotalSteps,
                onBack: {},
                onContinue: {
                    navigate(to: .waysToVerifyCompany)
                },
                onSkip: { Task { await startSkipVerificationFlow() } },
                onHowItWorks: {
                    openURL(verificationInfoURL)
                },
                showsHeader: false
            )
        case .waysToVerifyCompany:
            WaysToVerifyView(
                options: [
                    VerificationOption(id: "company_email", title: "Company Email"),
                    VerificationOption(id: "photo_id", title: "Work ID / Work Badge")
                ],
                currentStep: verificationStep(for: .waysToVerifyCompany),
                totalSteps: verificationTotalSteps,
                selectedOptionId: $companyVerificationOptionId,
                onBack: {},
                onContinue: { option in
                    let method = VerificationMethod.from(optionId: option.id)
                    verificationContext = VerificationContext(isLegacyFlow: false, method: method)
                    onboardingStore.saveVerificationMethod(method == .photoId ? "photo_id" : "email")
                    let target: AuthScreen = method == .photoId
                        ? .photoIdVerification(isLegacyFlow: false)
                        : .emailVerification(isLegacyFlow: false)
                    setNavigationStack(for: target)
                    Task {
                        _ = await authViewModel.setOnboardingV2VerificationChoice(path: method.v2Path)
                    }
                },
                onSkip: { Task { await startSkipVerificationFlow() } },
                onLearnMore: {
                    openURL(verificationInfoURL)
                },
                showsHeader: false
            )
        case .waysToVerifyLegacy:
            WaysToVerifyView(
                options: [
                    VerificationOption(id: "company_email", title: "Company Email"),
                    VerificationOption(id: "photo_id", title: "Work ID / Work Badge")
                ],
                currentStep: verificationStep(for: .waysToVerifyCompany),
                totalSteps: verificationTotalSteps,
                selectedOptionId: $companyVerificationOptionId,
                onBack: {},
                onContinue: { option in
                    let method = VerificationMethod.from(optionId: option.id)
                    verificationContext = VerificationContext(isLegacyFlow: false, method: method)
                    onboardingStore.saveVerificationMethod(method == .photoId ? "photo_id" : "email")
                    let target: AuthScreen = method == .photoId
                        ? .photoIdVerification(isLegacyFlow: false)
                        : .emailVerification(isLegacyFlow: false)
                    setNavigationStack(for: target)
                    Task {
                        _ = await authViewModel.setOnboardingV2VerificationChoice(path: method.v2Path)
                    }
                },
                onSkip: { Task { await startSkipVerificationFlow() } },
                onLearnMore: {
                    openURL(verificationInfoURL)
                },
                showsHeader: false
            )
        case .photoIdVerification(let isLegacyFlow):
            PhotoIdVerificationView(
                communityId: selectedCommunityId,
                currentStep: verificationStep(for: .photoIdVerification(isLegacyFlow: isLegacyFlow)),
                totalSteps: verificationTotalSteps,
                onBack: {},
                onSkip: { Task { await startSkipVerificationFlow() } },
                onComplete: {
                    if verificationContext == nil {
                        verificationContext = VerificationContext(isLegacyFlow: isLegacyFlow, method: .photoId)
                        onboardingStore.saveVerificationMethod("photo_id")
                    }
                    Task {
                        await feedViewModel.loadFollowedCommunities(reset: true)
                    }
                    pushIfNeeded(.photoPendingExplainer)
                },
                showsHeader: false
            )
        case .emailVerification(let isLegacyFlow):
            EmailVerificationView(
                communityId: selectedCommunityId,
                communityName: selectedLoopName,
                currentStep: verificationStep(for: .emailVerification(isLegacyFlow: isLegacyFlow)),
                totalSteps: verificationTotalSteps,
                onBack: {},
                onSkip: { Task { await startSkipVerificationFlow() } },
                onComplete: {
                    if verificationContext == nil {
                        verificationContext = VerificationContext(isLegacyFlow: isLegacyFlow, method: .email)
                        onboardingStore.saveVerificationMethod("email")
                    }
                    return await completeOnboardingEmailVerification(isLegacyFlow: isLegacyFlow)
                },
                showsHeader: false,
                ensureOnboardingVerificationStep: {
                    _ = await authViewModel.setOnboardingV2VerificationChoice(path: VerificationMethod.email.v2Path)
                }
            )
        case .verificationConfirmation:
            VerificationConfirmationView(
                authViewModel: authViewModel,
                currentStep: verificationStep(for: .verificationConfirmation),
                totalSteps: verificationTotalSteps,
                onBack: {},
                onSkip: nil,
                onComplete: {
                    Task {
                        _ = await authViewModel.finalizeOnboardingV2()
                    }
                },
                showsHeader: false,
                confirmationKind: .emailVerifiedAndJoined(loopName: selectedLoopName)
            )
        case .skipVerificationExplainer:
            OnboardingVerificationExplainerView(
                title: "You skipped verification",
                message: "You can verify later anytime in settings or on a community page. You can post, like, and comment only in communities where you’re verified.",
                buttonTitle: "Continue",
                illustrationAssetName: "skipped-verification",
                illustrationMaxWidth: 360,
                illustrationMaxHeight: 270,
                titleFont: .loopedHeadingMedium28,
                messageFont: .loopedBody,
                onBack: {
                    let isLegacyFlow = isLegacyOnboardingFlow
                    setNavigationStack(for: .verificationIntro(isLegacyFlow: isLegacyFlow))
                },
                onContinue: {
                    Task {
                        let acknowledged = await authViewModel.acknowledgeOnboardingV2SkipExplainer()
                        guard acknowledged else { return }
                        _ = await authViewModel.finalizeOnboardingV2()
                    }
                }
            )
        case .photoPendingExplainer:
            OnboardingVerificationExplainerView(
                title: "Verification is in review",
                message: "While we review your company verification, you can browse. Once approved, search and join fields.",
                buttonTitle: "Continue",
                illustrationMaxWidth: 330,
                illustrationMaxHeight: 240,
                titleFont: .loopedHeaderProfile,
                messageFont: .loopedBody,
                onContinue: {
                    Task {
                        let acknowledged = await authViewModel.acknowledgeOnboardingV2PhotoPendingExplainer()
                        guard acknowledged else { return }
                        _ = await authViewModel.finalizeOnboardingV2()
                    }
                }
            )
        case .login:
            LoginView(viewModel: authViewModel)
        case .signUp:
            SignUpView(viewModel: authViewModel)
        }
    }

    func navigate(to screen: AuthScreen) {
        if screen == .onboarding {
            path.removeAll()
            return
        }
        pushIfNeeded(screen)
    }

    func pushIfNeeded(_ screen: AuthScreen) {
        guard path.last != screen else { return }
        path.append(screen)
    }

    func popOne() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    struct VerificationContext {
        let isLegacyFlow: Bool
        let method: VerificationMethod
    }

    enum VerificationFlowMode {
        case full
        case skipped
    }

    enum VerificationMethod: Equatable {
        case photoId
        case email

        static func from(optionId: String) -> VerificationMethod {
            optionId == "photo_id" ? .photoId : .email
        }

        var v2Path: String {
            switch self {
            case .photoId:
                return "photo_id"
            case .email:
                return "email"
            }
        }
    }

    var verificationTotalSteps: Int {
        verificationFlowMode == .full ? 4 : 1
    }

    func verificationStep(for screen: AuthScreen) -> Int {
        guard verificationFlowMode == .full else { return 1 }
        switch screen {
        case .verificationIntro:
            return 1
        case .waysToVerifyCompany, .waysToVerifyLegacy:
            return 2
        case .photoIdVerification, .emailVerification:
            return 3
        case .verificationConfirmation:
            return 4
        default:
            return 1
        }
    }

    func startSkipVerificationFlow() async {
        verificationContext = nil
        onboardingStore.clearVerificationMethod()
        let choiceSet = await authViewModel.setOnboardingV2VerificationChoice(path: "skip")
        guard choiceSet else {
            restoreOnboardingScreen()
            return
        }
        restoreOnboardingScreen()
    }

    @MainActor
    func completeOnboardingEmailVerification(isLegacyFlow: Bool) async -> Bool {
        var success = await authViewModel.markOnboardingV2EmailVerificationSuccess()

        // If onboarding-v2 wasn't aligned yet, re-assert email path and retry once.
        if !success {
            let choiceSynced = await authViewModel.setOnboardingV2VerificationChoice(path: VerificationMethod.email.v2Path)
            if choiceSynced {
                success = await authViewModel.markOnboardingV2EmailVerificationSuccess()
            }
        }

        if !success {
            await authViewModel.loadCurrentUser()
            restoreOnboardingScreen()
            return false
        }

        restoreOnboardingScreen()

        if path.last != .emailVerification(isLegacyFlow: isLegacyFlow) || authViewModel.onboardingComplete {
            Task {
                await feedViewModel.loadFollowedCommunities(reset: true)
            }
            return true
        }

        // Backend onboarding context can lag briefly after verification success.
        if path.last == .emailVerification(isLegacyFlow: isLegacyFlow), !authViewModel.onboardingComplete {
            for _ in 0..<2 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                await authViewModel.loadCurrentUser()
                restoreOnboardingScreen()
                if path.last != .emailVerification(isLegacyFlow: isLegacyFlow) || authViewModel.onboardingComplete {
                    break
                }
            }
        }

        if path.last == .emailVerification(isLegacyFlow: isLegacyFlow), !authViewModel.onboardingComplete {
            let fallbackTarget: AuthScreen
            if authViewModel.onboardingContextV2?.specializationId != nil
                || authViewModel.onboardingContextV2?.specializationRequired == false {
                fallbackTarget = .verificationConfirmation
            } else {
                fallbackTarget = .departmentSelection
            }
            setNavigationStack(for: fallbackTarget)
        }

        let advanced = path.last != .emailVerification(isLegacyFlow: isLegacyFlow) || authViewModel.onboardingComplete
        if advanced {
            Task {
                await feedViewModel.loadFollowedCommunities(reset: true)
            }
        }
        return advanced
    }

    func submitOnboardingSpecializations(_ selections: [CommunitySearchResult]) async {
        let uniqueSelections = deduplicatedSpecializations(selections)
        guard let primarySelection = uniqueSelections.first else {
            logOnboardingDebug("specialization continue blocked: empty selection")
            return
        }

        logOnboardingDebug("specialization continue tapped: primary=\(primarySelection.id), all=\(uniqueSelections.map(\.id)), stage=\(authViewModel.onboardingStageV2 ?? "nil"), allowed=\(authViewModel.onboardingAllowedNextStagesV2)")

        var primarySubmitted = await authViewModel.submitOnboardingV2Specialization(specializationId: primarySelection.id)
        if !primarySubmitted {
            await authViewModel.loadCurrentUser()
            let normalizedStage = authViewModel.onboardingStageV2?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            let normalizedAllowed = Set(authViewModel.onboardingAllowedNextStagesV2.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            })
            let shouldRetryPrimary = normalizedStage == "specialization_selection"
                || normalizedStage == "specialization_required"
                || normalizedAllowed.contains("specialization_selection")
                || normalizedAllowed.contains("specialization_required")
            logOnboardingDebug("specialization primary failed; refreshed stage=\(normalizedStage), allowed=\(normalizedAllowed), retry=\(shouldRetryPrimary)")
            if shouldRetryPrimary {
                primarySubmitted = await authViewModel.submitOnboardingV2Specialization(specializationId: primarySelection.id)
            }
        }

        guard primarySubmitted else {
            restoreOnboardingScreen()
            return
        }

        NotificationCenter.default.post(
            name: .communityStateChanged,
            object: nil,
            userInfo: [LoopedNotificationUserInfoKey.communityId: primarySelection.id]
        )

        for additionalSelection in uniqueSelections.dropFirst() {
            do {
                try await communityService.joinSpecialization(id: additionalSelection.id)
                NotificationCenter.default.post(
                    name: .communityStateChanged,
                    object: nil,
                    userInfo: [LoopedNotificationUserInfoKey.communityId: additionalSelection.id]
                )
            } catch {
                logOnboardingDebug("secondary specialization join failed: id=\(additionalSelection.id), error=\(error.localizedDescription)")
            }
        }

        if uniqueSelections.count > 1 {
            await feedViewModel.loadFollowedCommunities(reset: true)
        }

        if authViewModel.onboardingComplete {
            restoreOnboardingScreen()
            return
        }

        // A successful onboarding-v2 specialization submit should allow finalization.
        // Some backend responses can remain at specialization_selection transiently,
        // so advance directly to confirmation to avoid trapping users on this screen.
        setNavigationStack(for: .verificationConfirmation)
    }

    func deduplicatedSpecializations(_ selections: [CommunitySearchResult]) -> [CommunitySearchResult] {
        var seen = Set<Int>()
        return selections.filter { seen.insert($0.id).inserted }
    }

    func followCommunityIfPossible(_ communityId: Int?) {
        guard let communityId else { return }
        Task {
            try? await communityService.followCommunity(id: communityId)
        }
    }

    func logOnboardingDebug(_ message: String) {
        #if DEBUG
        print("[OnboardingDebug] \(message)")
        #endif
    }

    func debugName(_ screen: AuthScreen?) -> String {
        guard let screen else { return "nil" }
        switch screen {
        case .onboarding: return "onboarding"
        case .profileSetup: return "profileSetup"
        case .verificationInfo: return "verificationInfo"
        case .selectCompany: return "selectCompany"
        case .selectOrganizationLegacy: return "selectOrganizationLegacy"
        case .departmentSelection: return "departmentSelection"
        case .fieldSelectionLegacy: return "fieldSelectionLegacy"
        case .verificationIntro(let isLegacyFlow): return "verificationIntro(\(isLegacyFlow ? "legacy" : "company"))"
        case .waysToVerifyCompany: return "waysToVerifyCompany"
        case .waysToVerifyLegacy: return "waysToVerifyLegacy"
        case .photoIdVerification(let isLegacyFlow): return "photoIdVerification(\(isLegacyFlow ? "legacy" : "company"))"
        case .emailVerification(let isLegacyFlow): return "emailVerification(\(isLegacyFlow ? "legacy" : "company"))"
        case .skipVerificationExplainer: return "skipVerificationExplainer"
        case .photoPendingExplainer: return "photoPendingExplainer"
        case .verificationConfirmation: return "verificationConfirmation"
        case .login: return "login"
        case .signUp: return "signUp"
        }
    }
}

enum AuthScreen: Hashable {
    case onboarding
    case profileSetup
    case verificationInfo
    case selectCompany
    case selectOrganizationLegacy
    case departmentSelection
    case fieldSelectionLegacy
    case verificationIntro(isLegacyFlow: Bool)
    case waysToVerifyCompany
    case waysToVerifyLegacy
    case photoIdVerification(isLegacyFlow: Bool)
    case emailVerification(isLegacyFlow: Bool)
    case skipVerificationExplainer
    case photoPendingExplainer
    case verificationConfirmation
    case login
    case signUp
}

private extension AuthView {
    func restoreOnboardingScreen() {
        guard !authViewModel.onboardingComplete else { return }
        restoreOrganizationDraftIfNeeded()
        restoreVerificationContextIfNeeded()
        let target = OnboardingRoutingResolver.resolveScreen(
            remoteStageV2: authViewModel.onboardingStageV2,
            remoteContext: authViewModel.onboardingContextV2,
            allowedNextStagesV2: authViewModel.onboardingAllowedNextStagesV2,
            remoteStep: authViewModel.onboardingStep,
            localStep: onboardingStore.loadProgress(),
            isLegacyFlow: isLegacyOnboardingFlow,
            shouldEnterOnboardingFlow: authViewModel.shouldEnterOnboardingFlow
        )
        guard let target else { return }
        let resolvedTarget = requiresOrganizationSelection(target) ? .selectCompany : target
        logOnboardingDebug(
            "restore resolved: remoteStage=\(authViewModel.onboardingStageV2 ?? "nil"), allowed=\(authViewModel.onboardingAllowedNextStagesV2), remoteStep=\(authViewModel.onboardingStep?.rawValue ?? "nil"), localStep=\(onboardingStore.loadProgress()?.rawValue ?? "nil"), target=\(debugName(target)), resolved=\(debugName(resolvedTarget)), selectedOrgId=\(authViewModel.selectedOrganization?.backendId?.description ?? "nil"), pathLast=\(debugName(path.last))"
        )
        if path.last == .verificationInfo, resolvedTarget == .selectCompany {
            persistProgress(for: .verificationInfo)
            return
        }
        let nextStack = navigationStack(for: resolvedTarget)
        if path != nextStack {
            path = nextStack
        }
        persistProgress(for: resolvedTarget)
    }

    func setNavigationStack(for screen: AuthScreen) {
        let nextStack = navigationStack(for: screen)
        if path != nextStack {
            path = nextStack
        }
    }

    func navigationStack(for screen: AuthScreen) -> [AuthScreen] {
        switch screen {
        case .onboarding:
            return []
        case .profileSetup:
            return [.profileSetup]
        case .verificationInfo:
            return [.profileSetup, .verificationInfo]
        case .selectCompany:
            return [.profileSetup, .verificationInfo, .selectCompany]
        case .selectOrganizationLegacy:
            return navigationStack(for: .selectCompany)
        case .verificationIntro(let isLegacyFlow):
            return [.profileSetup, .verificationInfo, .selectCompany, .verificationIntro(isLegacyFlow: isLegacyFlow)]
        case .waysToVerifyCompany:
            return navigationStack(for: .verificationIntro(isLegacyFlow: false)) + [.waysToVerifyCompany]
        case .waysToVerifyLegacy:
            return navigationStack(for: .waysToVerifyCompany)
        case .photoIdVerification(let isLegacyFlow):
            return navigationStack(for: .waysToVerifyCompany)
                + [.photoIdVerification(isLegacyFlow: isLegacyFlow)]
        case .emailVerification(let isLegacyFlow):
            return navigationStack(for: .waysToVerifyCompany)
                + [.emailVerification(isLegacyFlow: isLegacyFlow)]
        case .departmentSelection:
            return navigationStack(for: .emailVerification(isLegacyFlow: false)) + [.departmentSelection]
        case .fieldSelectionLegacy:
            return navigationStack(for: .departmentSelection)
        case .skipVerificationExplainer:
            return navigationStack(for: .verificationIntro(isLegacyFlow: false)) + [.skipVerificationExplainer]
        case .photoPendingExplainer:
            let isLegacyFlow = verificationContext?.isLegacyFlow ?? isLegacyOnboardingFlow
            return navigationStack(for: .photoIdVerification(isLegacyFlow: isLegacyFlow)) + [.photoPendingExplainer]
        case .verificationConfirmation:
            let specializationScreen: AuthScreen = .departmentSelection
            return navigationStack(for: specializationScreen) + [.verificationConfirmation]
        case .login:
            return [.login]
        case .signUp:
            return [.signUp]
        }
    }

    func persistProgress(for screen: AuthScreen) {
        guard let step = screen.onboardingStep else {
            onboardingStore.clearProgress()
            return
        }
        onboardingStore.saveProgress(step)
    }

    var isLegacyOnboardingFlow: Bool {
        return false
    }

    func restoreOrganizationDraftIfNeeded() {
        guard authViewModel.selectedOrganization == nil else { return }
        if let context = authViewModel.onboardingContextV2,
           let orgId = context.selectedOrgId,
           let orgName = context.selectedOrgName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !orgName.isEmpty {
            authViewModel.selectedOrganization = Organization(
                backendId: orgId,
                name: orgName,
                category: "",
                logoText: Organization.logoText(for: orgName),
                imageURL: nil,
                kind: .company
            )
            selectedLoopName = orgName
            selectedCommunityId = orgId
            return
        }

        guard let draft = onboardingStore.loadOrganizationDraft() else { return }

        authViewModel.selectedOrganization = Organization(
            backendId: draft.backendId,
            name: draft.name,
            category: "",
            logoText: Organization.logoText(for: draft.name),
            imageURL: draft.imageURL,
            kind: draft.kind
        )
        if selectedLoopName == "Looped" {
            selectedLoopName = draft.name
        }
        if selectedCommunityId == nil {
            selectedCommunityId = draft.backendId
        }
    }

    func restoreVerificationContextIfNeeded() {
        guard verificationContext == nil else { return }
        if let path = authViewModel.onboardingContextV2?.verificationPath?.lowercased() {
            switch path {
            case "email":
                verificationContext = VerificationContext(isLegacyFlow: isLegacyOnboardingFlow, method: .email)
                return
            case "photo_id":
                verificationContext = VerificationContext(isLegacyFlow: isLegacyOnboardingFlow, method: .photoId)
                return
            default:
                break
            }
        }
        guard let stored = onboardingStore.loadVerificationMethod() else { return }
        let method: VerificationMethod = stored == "photo_id" ? .photoId : .email
        verificationContext = VerificationContext(isLegacyFlow: isLegacyOnboardingFlow, method: method)
    }

    func requiresOrganizationSelection(_ screen: AuthScreen) -> Bool {
        guard authViewModel.selectedOrganization == nil else { return false }
        switch screen {
        case .departmentSelection, .fieldSelectionLegacy:
            return true
        case .verificationIntro,
             .waysToVerifyCompany,
             .waysToVerifyLegacy,
             .photoIdVerification,
             .emailVerification,
             .skipVerificationExplainer,
             .photoPendingExplainer,
             .verificationConfirmation:
            return true
        default:
            return false
        }
    }
}

struct OnboardingRoutingResolver {
    static func resolveScreen(
        remoteStageV2: String?,
        remoteContext: OnboardingContextV2DTO?,
        allowedNextStagesV2: [String]? = nil,
        remoteStep: RemoteOnboardingStep?,
        localStep: OnboardingStep?,
        isLegacyFlow: Bool,
        shouldEnterOnboardingFlow: Bool
    ) -> AuthScreen? {
        let resolvedIsLegacyFlow = isLegacyFlow
        let verificationPath = remoteContext?.verificationPath?.lowercased()
        let verificationStatus = remoteContext?.verificationStatus?.lowercased()
        let requiresSpecialization = remoteContext?.specializationRequired ?? false
        let hasSpecialization = remoteContext?.specializationId != nil
        let normalizedAllowedNextStages = Set((allowedNextStagesV2 ?? []).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        if let remoteStageV2 {
            let normalizedStage = remoteStageV2.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch normalizedStage {
            case "completed", "finalized":
                return nil
            case "profile_setup":
                return .profileSetup
            case "info_screen", "verification_info":
                return .verificationInfo
            case "org_selection", "select_company", "org_selected":
                if shouldHoldOnVerificationInfo(localStep: localStep) {
                    return .verificationInfo
                }
                if normalizedStage == "org_selected" {
                    if let allowedNextFallback = resolveFromAllowedNextStages(
                        normalizedAllowedNextStages,
                        isLegacyFlow: resolvedIsLegacyFlow
                    ) {
                        return allowedNextFallback
                    }
                    return .verificationIntro(isLegacyFlow: resolvedIsLegacyFlow)
                }
                return .selectCompany
            case "verification_intro":
                return .verificationIntro(isLegacyFlow: resolvedIsLegacyFlow)
            case "verification_choice", "ways_to_verify":
                return .waysToVerifyCompany
            case "email_verification":
                let isEmailCompatiblePath = verificationPath == nil || verificationPath == "email"
                if isEmailCompatiblePath, isEmailVerificationApproved(verificationStatus) {
                    if hasSpecialization
                        || normalizedAllowedNextStages.contains("completed")
                        || normalizedAllowedNextStages.contains("finalized")
                        || normalizedAllowedNextStages.contains("ready_to_finalize") {
                        return .verificationConfirmation
                    }
                    if requiresSpecialization
                        || normalizedAllowedNextStages.contains("specialization_selection")
                        || normalizedAllowedNextStages.contains("specialization_required") {
                        return .departmentSelection
                    }
                    return .verificationConfirmation
                }
                return .emailVerification(isLegacyFlow: resolvedIsLegacyFlow)
            case "photo_id_verification", "photo_verification":
                return .photoIdVerification(isLegacyFlow: resolvedIsLegacyFlow)
            case "email_verified", "specialization_selection", "specialization_required":
                if normalizedAllowedNextStages.contains("completed")
                    || normalizedAllowedNextStages.contains("finalized")
                    || normalizedAllowedNextStages.contains("ready_to_finalize") {
                    return .verificationConfirmation
                }
                return .departmentSelection
            case "skip_explainer":
                return .skipVerificationExplainer
            case "photo_pending_explainer", "photo_id_pending_explainer":
                return .photoPendingExplainer
            case "specialization_selected", "ready_to_finalize":
                return .verificationConfirmation
            default:
                if normalizedStage.contains("specialization") {
                    return .departmentSelection
                }
                if let allowedNextFallback = resolveFromAllowedNextStages(
                    normalizedAllowedNextStages,
                    isLegacyFlow: resolvedIsLegacyFlow
                ) {
                    return allowedNextFallback
                }
            }
        }

        if verificationPath == "skip" {
            return .skipVerificationExplainer
        }
        if verificationPath == "photo_id" {
            return verificationStatus == "pending" ? .photoPendingExplainer : .photoIdVerification(isLegacyFlow: resolvedIsLegacyFlow)
        }
        if verificationPath == "email" {
            if hasSpecialization || (requiresSpecialization && verificationStatus == "approved") {
                return hasSpecialization ? .verificationConfirmation : .departmentSelection
            }
            return .emailVerification(isLegacyFlow: resolvedIsLegacyFlow)
        }
        if verificationPath == nil, isEmailVerificationApproved(verificationStatus) {
            if hasSpecialization {
                return .verificationConfirmation
            }
            if requiresSpecialization {
                return .departmentSelection
            }
            return .verificationConfirmation
        }

        if let allowedNextFallback = resolveFromAllowedNextStages(
            normalizedAllowedNextStages,
            isLegacyFlow: resolvedIsLegacyFlow
        ) {
            return allowedNextFallback
        }

        if let remoteStep,
           remoteStep == .selectCompany,
           shouldHoldOnVerificationInfo(localStep: localStep) {
            return .verificationInfo
        }

        if let remoteStep,
           let remote = AuthScreen.fromRemoteOnboardingStep(remoteStep, isLegacyFlow: resolvedIsLegacyFlow) {
            return remote
        }
        guard shouldEnterOnboardingFlow else { return nil }
        if let localStep {
            return sanitizedLocalScreen(from: localStep)
        }
        return .profileSetup
    }

    static func sanitizedLocalScreen(from step: OnboardingStep) -> AuthScreen? {
        guard let raw = AuthScreen.fromOnboardingStep(step) else { return nil }
        switch raw {
        case .departmentSelection, .fieldSelectionLegacy:
            return .selectCompany
        case .verificationIntro(isLegacyFlow: _):
            return .selectCompany
        case .waysToVerifyCompany,
             .photoIdVerification(isLegacyFlow: false),
             .emailVerification(isLegacyFlow: false):
            return .selectCompany
        case .waysToVerifyLegacy,
             .photoIdVerification(isLegacyFlow: true),
             .emailVerification(isLegacyFlow: true):
            return .selectCompany
        case .verificationConfirmation:
            return .selectCompany
        case .skipVerificationExplainer:
            return .selectCompany
        case .photoPendingExplainer:
            return .selectCompany
        default:
            return raw
        }
    }

    private static func shouldHoldOnVerificationInfo(localStep: OnboardingStep?) -> Bool {
        switch localStep {
        case .none, .profileSetup?, .verificationInfo?:
            return true
        default:
            return false
        }
    }

    private static func resolveFromAllowedNextStages(
        _ allowed: Set<String>,
        isLegacyFlow: Bool
    ) -> AuthScreen? {
        if allowed.contains("completed") || allowed.contains("finalized") || allowed.contains("ready_to_finalize") {
            return .verificationConfirmation
        }
        if allowed.contains("skip_explainer") {
            return .skipVerificationExplainer
        }
        if allowed.contains("specialization_selection") || allowed.contains("specialization_required") {
            return .departmentSelection
        }
        if allowed.contains("email_verification") {
            return .emailVerification(isLegacyFlow: isLegacyFlow)
        }
        if allowed.contains("photo_id_verification") || allowed.contains("photo_verification") {
            return .photoIdVerification(isLegacyFlow: isLegacyFlow)
        }
        if allowed.contains("verification_choice") || allowed.contains("ways_to_verify") {
            return .waysToVerifyCompany
        }
        if allowed.contains("verification_intro") {
            return .verificationIntro(isLegacyFlow: isLegacyFlow)
        }
        if allowed.contains("org_selection") || allowed.contains("org_selected") || allowed.contains("select_company") {
            return .selectCompany
        }
        return nil
    }

    private static func isEmailVerificationApproved(_ status: String?) -> Bool {
        guard let normalized = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !normalized.isEmpty else {
            return false
        }
        switch normalized {
        case "approved", "verified", "active", "success", "completed":
            return true
        default:
            return false
        }
    }
}

private extension AuthScreen {
    var onboardingStep: OnboardingStep? {
        switch self {
        case .profileSetup:
            return .profileSetup
        case .verificationInfo:
            return .verificationInfo
        case .selectCompany:
            return .selectCompany
        case .selectOrganizationLegacy:
            return .selectCompany
        case .departmentSelection:
            return .departmentSelection
        case .fieldSelectionLegacy:
            return .departmentSelection
        case .verificationIntro(let isLegacyFlow):
            return isLegacyFlow ? .verificationIntroLegacy : .verificationIntroCompany
        case .waysToVerifyCompany:
            return .waysToVerifyCompany
        case .waysToVerifyLegacy:
            return .waysToVerifyCompany
        case .photoIdVerification:
            return .photoIdVerificationCompany
        case .emailVerification:
            return .emailVerificationCompany
        case .verificationConfirmation:
            return .verificationConfirmation
        default:
            return nil
        }
    }

    static func fromOnboardingStep(_ step: OnboardingStep) -> AuthScreen? {
        switch step {
        case .profileSetup:
            return .profileSetup
        case .verificationInfo:
            return .verificationInfo
        case .selectCompany:
            return .selectCompany
        case .selectOrganizationLegacy:
            return .selectCompany
        case .departmentSelection:
            return .departmentSelection
        case .fieldSelectionLegacy:
            return .departmentSelection
        case .communitySelectionLegacy:
            return .verificationIntro(isLegacyFlow: false)
        case .communitySelectionCompany:
            return .verificationIntro(isLegacyFlow: false)
        case .verificationIntroLegacy:
            return .verificationIntro(isLegacyFlow: false)
        case .verificationIntroCompany:
            return .verificationIntro(isLegacyFlow: false)
        case .waysToVerifyCompany:
            return .waysToVerifyCompany
        case .waysToVerifyLegacy:
            return .waysToVerifyCompany
        case .photoIdVerificationLegacy:
            return .photoIdVerification(isLegacyFlow: false)
        case .photoIdVerificationCompany:
            return .photoIdVerification(isLegacyFlow: false)
        case .emailVerificationLegacy:
            return .emailVerification(isLegacyFlow: false)
        case .emailVerificationCompany:
            return .emailVerification(isLegacyFlow: false)
        case .verificationConfirmation:
            return .verificationConfirmation
        case .verificationNotifications:
            return .verificationConfirmation
        }
    }

    static func fromRemoteOnboardingStep(_ step: RemoteOnboardingStep, isLegacyFlow: Bool) -> AuthScreen? {
        switch step {
        case .profileSetup:
            return .profileSetup
        case .selectCompany:
            return .selectCompany
        case .verification:
            return .verificationIntro(isLegacyFlow: isLegacyFlow)
        case .verificationNotifications:
            return .verificationConfirmation
        }
    }
}

#Preview {
    AuthView(authViewModel: AuthViewModel())
        .environmentObject(FeedViewModel())
}
