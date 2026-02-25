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
    @State private var schoolSearchText: String = ""
    @State private var departmentSearchText: String = ""
    @State private var degreeSearchText: String = ""
    @State private var selectedDepartments: [CommunitySearchResult] = []
    @State private var selectedDegrees: [CommunitySearchResult] = []
    @State private var companyVerificationOptionId: String?
    @State private var studentVerificationOptionId: String?
    @State private var verificationContext: VerificationContext?
    private let onboardingStore = OnboardingProgressStore()
    @State private var verificationFlowMode: VerificationFlowMode = .full
    private let communityService: CommunityServiceProtocol = CommunityService()
    private let verificationInfoURL = URL(string: "https://www.mylooped.app/privacy")!
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
                title: "Search for your school or\nplace of work",
                scope: .companiesAndSchools,
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
        case .selectSchool:
            OrganizationSelectionView(
                title: "Select your school",
                scope: .schoolsOnly,
                searchText: $schoolSearchText,
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
                        logOnboardingDebug("school continue blocked: missing backendId for \(organization.name)")
                        return
                    }
                    logOnboardingDebug("school continue tapped: orgId=\(orgId), name=\(organization.name), stage=\(authViewModel.onboardingStageV2 ?? "nil"), local=\(onboardingStore.loadProgress()?.rawValue ?? "nil")")
                    Task {
                        let success = await authViewModel.setOnboardingV2Organization(orgId: orgId)
                        logOnboardingDebug("school org set result: success=\(success), stage=\(authViewModel.onboardingStageV2 ?? "nil"), allowed=\(authViewModel.onboardingAllowedNextStagesV2)")
                        guard success else {
                            await authViewModel.loadCurrentUser()
                            logOnboardingDebug("school org set failed; refreshed identity stage=\(authViewModel.onboardingStageV2 ?? "nil"), step=\(authViewModel.onboardingStep?.rawValue ?? "nil")")
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
        case .degreeSelection:
            OrganizationDetailSelectionView(
                title: "Major",
                kind: .major,
                searchText: $degreeSearchText,
                selectedItems: $selectedDegrees,
                maxSelections: 2,
                onSelect: { selections in
                    selectedDegrees = selections
                },
                onContinue: { selections in
                    Task {
                        await submitOnboardingSpecializations(selections)
                    }
                }
            )
        case .verificationIntro(let isStudent):
            VerificationIntroView(
                loopName: selectedLoopName,
                currentStep: verificationStep(for: .verificationIntro(isStudent: isStudent)),
                totalSteps: verificationTotalSteps,
                onBack: {},
                onContinue: {
                    navigate(to: isStudent ? .waysToVerifyStudent : .waysToVerifyCompany)
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
                    verificationContext = VerificationContext(isStudent: false, method: method)
                    onboardingStore.saveVerificationMethod(method == .photoId ? "photo_id" : "email")
                    let target: AuthScreen = method == .photoId
                        ? .photoIdVerification(isStudent: false)
                        : .emailVerification(isStudent: false)
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
        case .waysToVerifyStudent:
            WaysToVerifyView(
                options: [
                    VerificationOption(id: "student_email", title: "Student Email"),
                    VerificationOption(id: "photo_id", title: "Work ID / Work Badge")
                ],
                currentStep: verificationStep(for: .waysToVerifyStudent),
                totalSteps: verificationTotalSteps,
                selectedOptionId: $studentVerificationOptionId,
                onBack: {},
                onContinue: { option in
                    let method = VerificationMethod.from(optionId: option.id)
                    verificationContext = VerificationContext(isStudent: true, method: method)
                    onboardingStore.saveVerificationMethod(method == .photoId ? "photo_id" : "email")
                    let target: AuthScreen = method == .photoId
                        ? .photoIdVerification(isStudent: true)
                        : .emailVerification(isStudent: true)
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
        case .photoIdVerification(let isStudent):
            PhotoIdVerificationView(
                communityId: selectedCommunityId,
                currentStep: verificationStep(for: .photoIdVerification(isStudent: isStudent)),
                totalSteps: verificationTotalSteps,
                onBack: {},
                onSkip: { Task { await startSkipVerificationFlow() } },
                onComplete: {
                    if verificationContext == nil {
                        verificationContext = VerificationContext(isStudent: isStudent, method: .photoId)
                        onboardingStore.saveVerificationMethod("photo_id")
                    }
                    Task {
                        await feedViewModel.loadFollowedCommunities(reset: true)
                    }
                    pushIfNeeded(.photoPendingExplainer)
                },
                showsHeader: false
            )
        case .emailVerification(let isStudent):
            EmailVerificationView(
                communityId: selectedCommunityId,
                communityName: selectedLoopName,
                currentStep: verificationStep(for: .emailVerification(isStudent: isStudent)),
                totalSteps: verificationTotalSteps,
                onBack: {},
                onSkip: { Task { await startSkipVerificationFlow() } },
                onComplete: {
                    if verificationContext == nil {
                        verificationContext = VerificationContext(isStudent: isStudent, method: .email)
                        onboardingStore.saveVerificationMethod("email")
                    }
                    Task {
                        await feedViewModel.loadFollowedCommunities(reset: true)
                        let success = await authViewModel.markOnboardingV2EmailVerificationSuccess()
                        guard success else {
                            restoreOnboardingScreen()
                            return
                        }
                        restoreOnboardingScreen()
                    }
                },
                showsHeader: false
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
                    let isStudent = isStudentOnboardingFlow
                    setNavigationStack(for: .verificationIntro(isStudent: isStudent))
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
                message: "While we review your \(isStudentOnboardingFlow ? "school" : "company") verification, you can browse. Once approved, search and join majors or fields.",
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
        let isStudent: Bool
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
        case .waysToVerifyCompany, .waysToVerifyStudent:
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
        case .selectSchool: return "selectSchool"
        case .departmentSelection: return "departmentSelection"
        case .degreeSelection: return "degreeSelection"
        case .verificationIntro(let isStudent): return "verificationIntro(\(isStudent ? "student" : "company"))"
        case .waysToVerifyCompany: return "waysToVerifyCompany"
        case .waysToVerifyStudent: return "waysToVerifyStudent"
        case .photoIdVerification(let isStudent): return "photoIdVerification(\(isStudent ? "student" : "company"))"
        case .emailVerification(let isStudent): return "emailVerification(\(isStudent ? "student" : "company"))"
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
    case selectSchool
    case departmentSelection
    case degreeSelection
    case verificationIntro(isStudent: Bool)
    case waysToVerifyCompany
    case waysToVerifyStudent
    case photoIdVerification(isStudent: Bool)
    case emailVerification(isStudent: Bool)
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
            isStudent: isStudentOnboardingFlow,
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
        case .selectSchool:
            return [.profileSetup, .verificationInfo, .selectSchool]
        case .verificationIntro(let isStudent):
            return [.profileSetup, .verificationInfo, .selectCompany, .verificationIntro(isStudent: isStudent)]
        case .waysToVerifyCompany:
            return navigationStack(for: .verificationIntro(isStudent: false)) + [.waysToVerifyCompany]
        case .waysToVerifyStudent:
            return navigationStack(for: .verificationIntro(isStudent: true)) + [.waysToVerifyStudent]
        case .photoIdVerification(let isStudent):
            return navigationStack(for: isStudent ? .waysToVerifyStudent : .waysToVerifyCompany)
                + [.photoIdVerification(isStudent: isStudent)]
        case .emailVerification(let isStudent):
            return navigationStack(for: isStudent ? .waysToVerifyStudent : .waysToVerifyCompany)
                + [.emailVerification(isStudent: isStudent)]
        case .departmentSelection:
            return navigationStack(for: .emailVerification(isStudent: false)) + [.departmentSelection]
        case .degreeSelection:
            return navigationStack(for: .emailVerification(isStudent: true)) + [.degreeSelection]
        case .skipVerificationExplainer:
            let isStudent = authViewModel.onboardingContextV2?.selectedOrgKind?.lowercased() == "school"
            return navigationStack(for: .verificationIntro(isStudent: isStudent)) + [.skipVerificationExplainer]
        case .photoPendingExplainer:
            let isStudent = verificationContext?.isStudent ?? isStudentOnboardingFlow
            return navigationStack(for: .photoIdVerification(isStudent: isStudent)) + [.photoPendingExplainer]
        case .verificationConfirmation:
            let isStudent = verificationContext?.isStudent ?? isStudentOnboardingFlow
            let specializationScreen: AuthScreen = isStudent ? .degreeSelection : .departmentSelection
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

    var isStudentOnboardingFlow: Bool {
        if authViewModel.onboardingContextV2?.selectedOrgKind?.lowercased() == "school" {
            return true
        }
        if let kind = authViewModel.selectedOrganization?.kind {
            return kind == .school
        }
        if let stored = onboardingStore.loadOrganizationDraft() {
            return stored.kind == .school
        }
        return false
    }

    func restoreOrganizationDraftIfNeeded() {
        guard authViewModel.selectedOrganization == nil else { return }
        if let context = authViewModel.onboardingContextV2,
           let orgId = context.selectedOrgId,
           let orgName = context.selectedOrgName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !orgName.isEmpty {
            let kind: OrganizationKind = context.selectedOrgKind?.lowercased() == "school" ? .school : .company
            authViewModel.selectedOrganization = Organization(
                backendId: orgId,
                name: orgName,
                category: "",
                logoText: Organization.logoText(for: orgName),
                imageURL: nil,
                kind: kind
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
                verificationContext = VerificationContext(isStudent: isStudentOnboardingFlow, method: .email)
                return
            case "photo_id":
                verificationContext = VerificationContext(isStudent: isStudentOnboardingFlow, method: .photoId)
                return
            default:
                break
            }
        }
        guard let stored = onboardingStore.loadVerificationMethod() else { return }
        let method: VerificationMethod = stored == "photo_id" ? .photoId : .email
        verificationContext = VerificationContext(isStudent: isStudentOnboardingFlow, method: method)
    }

    func requiresOrganizationSelection(_ screen: AuthScreen) -> Bool {
        guard authViewModel.selectedOrganization == nil else { return false }
        switch screen {
        case .departmentSelection, .degreeSelection:
            return true
        case .verificationIntro,
             .waysToVerifyCompany,
             .waysToVerifyStudent,
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
        isStudent: Bool,
        shouldEnterOnboardingFlow: Bool
    ) -> AuthScreen? {
        let resolvedIsStudent = remoteContext?.selectedOrgKind?.lowercased() == "school" || isStudent
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
                        isStudent: resolvedIsStudent
                    ) {
                        return allowedNextFallback
                    }
                    return .verificationIntro(isStudent: resolvedIsStudent)
                }
                return .selectCompany
            case "verification_intro":
                return .verificationIntro(isStudent: resolvedIsStudent)
            case "verification_choice", "ways_to_verify":
                return resolvedIsStudent ? .waysToVerifyStudent : .waysToVerifyCompany
            case "email_verification":
                if verificationPath == "email", isEmailVerificationApproved(verificationStatus) {
                    if hasSpecialization
                        || normalizedAllowedNextStages.contains("completed")
                        || normalizedAllowedNextStages.contains("finalized")
                        || normalizedAllowedNextStages.contains("ready_to_finalize") {
                        return .verificationConfirmation
                    }
                    if requiresSpecialization
                        || normalizedAllowedNextStages.contains("specialization_selection")
                        || normalizedAllowedNextStages.contains("specialization_required") {
                        return resolvedIsStudent ? .degreeSelection : .departmentSelection
                    }
                    return .verificationConfirmation
                }
                return .emailVerification(isStudent: resolvedIsStudent)
            case "photo_id_verification", "photo_verification":
                return .photoIdVerification(isStudent: resolvedIsStudent)
            case "email_verified", "specialization_selection", "specialization_required":
                if normalizedAllowedNextStages.contains("completed")
                    || normalizedAllowedNextStages.contains("finalized")
                    || normalizedAllowedNextStages.contains("ready_to_finalize") {
                    return .verificationConfirmation
                }
                return resolvedIsStudent ? .degreeSelection : .departmentSelection
            case "skip_explainer":
                return .skipVerificationExplainer
            case "photo_pending_explainer", "photo_id_pending_explainer":
                return .photoPendingExplainer
            case "specialization_selected", "ready_to_finalize":
                return .verificationConfirmation
            default:
                if normalizedStage.contains("specialization") {
                    return resolvedIsStudent ? .degreeSelection : .departmentSelection
                }
                if let allowedNextFallback = resolveFromAllowedNextStages(
                    normalizedAllowedNextStages,
                    isStudent: resolvedIsStudent
                ) {
                    return allowedNextFallback
                }
            }
        }

        if verificationPath == "skip" {
            return .skipVerificationExplainer
        }
        if verificationPath == "photo_id" {
            return verificationStatus == "pending" ? .photoPendingExplainer : .photoIdVerification(isStudent: resolvedIsStudent)
        }
        if verificationPath == "email" {
            if hasSpecialization || (requiresSpecialization && verificationStatus == "approved") {
                return (hasSpecialization ? .verificationConfirmation : (resolvedIsStudent ? .degreeSelection : .departmentSelection))
            }
            return .emailVerification(isStudent: resolvedIsStudent)
        }

        if let allowedNextFallback = resolveFromAllowedNextStages(
            normalizedAllowedNextStages,
            isStudent: resolvedIsStudent
        ) {
            return allowedNextFallback
        }

        if let remoteStep,
           remoteStep == .selectCompany,
           shouldHoldOnVerificationInfo(localStep: localStep) {
            return .verificationInfo
        }

        if let remoteStep,
           let remote = AuthScreen.fromRemoteOnboardingStep(remoteStep, isStudent: resolvedIsStudent) {
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
        case .departmentSelection, .degreeSelection:
            return .selectCompany
        case .verificationIntro(isStudent: _):
            return .selectCompany
        case .waysToVerifyCompany,
             .photoIdVerification(isStudent: false),
             .emailVerification(isStudent: false):
            return .selectCompany
        case .waysToVerifyStudent,
             .photoIdVerification(isStudent: true),
             .emailVerification(isStudent: true):
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
        isStudent: Bool
    ) -> AuthScreen? {
        if allowed.contains("completed") || allowed.contains("finalized") || allowed.contains("ready_to_finalize") {
            return .verificationConfirmation
        }
        if allowed.contains("skip_explainer") {
            return .skipVerificationExplainer
        }
        if allowed.contains("specialization_selection") || allowed.contains("specialization_required") {
            return isStudent ? .degreeSelection : .departmentSelection
        }
        if allowed.contains("email_verification") {
            return .emailVerification(isStudent: isStudent)
        }
        if allowed.contains("photo_id_verification") || allowed.contains("photo_verification") {
            return .photoIdVerification(isStudent: isStudent)
        }
        if allowed.contains("verification_choice") || allowed.contains("ways_to_verify") {
            return isStudent ? .waysToVerifyStudent : .waysToVerifyCompany
        }
        if allowed.contains("verification_intro") {
            return .verificationIntro(isStudent: isStudent)
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
        case .selectSchool:
            return .selectSchool
        case .departmentSelection:
            return .departmentSelection
        case .degreeSelection:
            return .degreeSelection
        case .verificationIntro(let isStudent):
            return isStudent ? .verificationIntroStudent : .verificationIntroCompany
        case .waysToVerifyCompany:
            return .waysToVerifyCompany
        case .waysToVerifyStudent:
            return .waysToVerifyStudent
        case .photoIdVerification(let isStudent):
            return isStudent ? .photoIdVerificationStudent : .photoIdVerificationCompany
        case .emailVerification(let isStudent):
            return isStudent ? .emailVerificationStudent : .emailVerificationCompany
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
        case .selectSchool:
            return .selectSchool
        case .departmentSelection:
            return .departmentSelection
        case .degreeSelection:
            return .degreeSelection
        case .communitySelectionStudent:
            return .verificationIntro(isStudent: true)
        case .communitySelectionCompany:
            return .verificationIntro(isStudent: false)
        case .verificationIntroStudent:
            return .verificationIntro(isStudent: true)
        case .verificationIntroCompany:
            return .verificationIntro(isStudent: false)
        case .waysToVerifyCompany:
            return .waysToVerifyCompany
        case .waysToVerifyStudent:
            return .waysToVerifyStudent
        case .photoIdVerificationStudent:
            return .photoIdVerification(isStudent: true)
        case .photoIdVerificationCompany:
            return .photoIdVerification(isStudent: false)
        case .emailVerificationStudent:
            return .emailVerification(isStudent: true)
        case .emailVerificationCompany:
            return .emailVerification(isStudent: false)
        case .verificationConfirmation:
            return .verificationConfirmation
        case .verificationNotifications:
            return .verificationConfirmation
        }
    }

    static func fromRemoteOnboardingStep(_ step: RemoteOnboardingStep, isStudent: Bool) -> AuthScreen? {
        switch step {
        case .profileSetup:
            return .profileSetup
        case .selectCompany:
            return .selectCompany
        case .verification:
            return .verificationIntro(isStudent: isStudent)
        case .verificationNotifications:
            return .verificationConfirmation
        }
    }
}

#Preview {
    AuthView(authViewModel: AuthViewModel())
        .environmentObject(FeedViewModel())
}
