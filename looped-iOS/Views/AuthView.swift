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
    @State private var selectedDepartment: CommunitySearchResult?
    @State private var selectedDegree: CommunitySearchResult?
    @State private var companyVerificationOptionId: String?
    @State private var studentVerificationOptionId: String?
    @State private var verificationContext: VerificationContext?
    private let onboardingStore = OnboardingProgressStore()
    @State private var verificationFlowMode: VerificationFlowMode = .full
    @State private var lastReportedRemoteStep: RemoteOnboardingStep?
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
            reportRemoteProgressIfNeeded(for: screen)
        }
        .onChange(of: authViewModel.onboardingStep) { _, _ in
            if authViewModel.isAuthenticated, !authViewModel.onboardingComplete {
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
                    guard authViewModel.selectedOrganization != nil else {
                        onboardingStore.saveProgress(.verificationInfo)
                        navigate(to: .verificationInfo)
                        return
                    }
                    if authViewModel.onboardingStep == .verification
                        || authViewModel.onboardingStep == .verificationNotifications {
                        restoreOnboardingScreen()
                    } else {
                        onboardingStore.saveProgress(.verificationInfo)
                        navigate(to: .verificationInfo)
                    }
                }
            )
        case .verificationInfo:
            VerificationInfoOnboardingView {
                navigate(to: .selectCompany)
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
                    followCommunityIfPossible(organization.backendId)
                    navigate(to: organization.kind == .school ? .degreeSelection : .departmentSelection)
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
                    followCommunityIfPossible(organization.backendId)
                    navigate(to: organization.kind == .school ? .degreeSelection : .departmentSelection)
                }
            )
        case .departmentSelection:
            OrganizationDetailSelectionView(
                title: "Field",
                kind: .field,
                searchText: $departmentSearchText,
                selectedItem: $selectedDepartment,
                onSelect: { _ in },
                onContinue: { selection in
                    followSpecializationIfPossible(selection.id)
                    navigate(to: .verificationIntro(isStudent: false))
                }
            )
        case .degreeSelection:
            OrganizationDetailSelectionView(
                title: "Major",
                kind: .major,
                searchText: $degreeSearchText,
                selectedItem: $selectedDegree,
                onSelect: { _ in },
                onContinue: { selection in
                    followSpecializationIfPossible(selection.id)
                    navigate(to: .verificationIntro(isStudent: true))
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
                onSkip: {
                    skipToNotifications()
                },
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
	                    if method == .photoId {
	                        navigate(to: .photoIdVerification(isStudent: false))
	                    } else {
	                        navigate(to: .emailVerification(isStudent: false))
	                    }
	                },
                onSkip: {
                    skipToNotifications()
                },
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
	                    if method == .photoId {
	                        navigate(to: .photoIdVerification(isStudent: true))
	                    } else {
	                        navigate(to: .emailVerification(isStudent: true))
	                    }
	                },
                onSkip: {
                    skipToNotifications()
                },
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
                onSkip: {
                    skipToNotifications()
                },
	                onComplete: {
	                    if verificationContext == nil {
	                        verificationContext = VerificationContext(isStudent: isStudent, method: .photoId)
	                        onboardingStore.saveVerificationMethod("photo_id")
	                    }
                        Task {
                            await feedViewModel.loadFollowedCommunities(reset: true)
                        }
	                    pushIfNeeded(.verificationConfirmation)
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
                onSkip: {
                    skipToNotifications()
                },
                onComplete: {
                    if verificationContext == nil {
                        verificationContext = VerificationContext(isStudent: isStudent, method: .email)
                        onboardingStore.saveVerificationMethod("email")
                    }
                    Task {
                        await feedViewModel.loadFollowedCommunities(reset: true)
                    }
                    pushIfNeeded(.verificationConfirmation)
                },
                showsHeader: false,
                ensureOnboardingVerificationStep: {
                    await ensureOnboardingVerificationStepForCommunityEndpoints()
                }
            )
        case .verificationConfirmation:
            let confirmationKind: VerificationConfirmationView.ConfirmationKind = {
	                guard let verificationContext else { return .photoIdPending }
	                switch verificationContext.method {
	                case .email:
	                    return .emailVerified(loopName: selectedLoopName)
	                case .photoId:
	                    return .photoIdPending
	                }
	            }()
		            VerificationConfirmationView(
		                authViewModel: authViewModel,
		                currentStep: verificationStep(for: .verificationConfirmation),
		                totalSteps: verificationTotalSteps,
		                onBack: {},
		                onSkip: {
		                    skipToNotifications()
		                },
		                onComplete: {
		                    joinSelectedSpecializationAfterVerificationIfPossible()
                            Task {
                                await authViewModel.finishOnboardingFromNotificationsStep()
                            }
		                },
		                showsHeader: false,
		                confirmationKind: confirmationKind
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

	    func skipToNotifications() {
	        verificationContext = nil
	        onboardingStore.clearVerificationMethod()
            Task {
                await authViewModel.finishOnboardingFromNotificationsStep()
            }
    }

    func followCommunityIfPossible(_ communityId: Int?) {
        guard let communityId else { return }
        Task {
            try? await communityService.followCommunity(id: communityId)
        }
    }

	    func followSpecializationIfPossible(_ specializationId: Int?) {
	        guard let specializationId else { return }
	        Task {
	            try? await communityService.followSpecialization(id: specializationId)
	        }
	    }

    func joinSelectedSpecializationAfterVerificationIfPossible() {
        guard verificationContext?.method == .email else { return }
        let isStudent = verificationContext?.isStudent ?? isStudentOnboardingFlow
        let specializationId = isStudent ? selectedDegree?.id : selectedDepartment?.id
        guard let specializationId else { return }
        Task {
            do {
                try await communityService.joinSpecialization(id: specializationId)
                NotificationCenter.default.post(
                    name: .communityStateChanged,
                    object: nil,
                    userInfo: [LoopedNotificationUserInfoKey.communityId: specializationId]
                )
            } catch {
                // Best-effort: specialization join shouldn't block onboarding completion.
            }
        }
    }

	    // Intentionally no "pick communities" step in onboarding; users only choose their org + field/major.
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
            remoteStep: authViewModel.onboardingStep,
            localStep: onboardingStore.loadProgress(),
            isStudent: isStudentOnboardingFlow,
            shouldEnterOnboardingFlow: authViewModel.shouldEnterOnboardingFlow
        )
        guard let target else { return }
        let resolvedTarget = requiresOrganizationSelection(target) ? .selectCompany : target
        setNavigationStack(for: resolvedTarget)
        persistProgress(for: resolvedTarget)
    }

    func setNavigationStack(for screen: AuthScreen) {
        path = navigationStack(for: screen)
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
        case .departmentSelection:
            return [.profileSetup, .verificationInfo, .selectCompany, .departmentSelection]
        case .degreeSelection:
            return [.profileSetup, .verificationInfo, .selectCompany, .degreeSelection]
        case .verificationIntro(let isStudent):
            let base: [AuthScreen] = isStudent
                ? [.profileSetup, .verificationInfo, .selectCompany, .degreeSelection]
                : [.profileSetup, .verificationInfo, .selectCompany, .departmentSelection]
            return base + [.verificationIntro(isStudent: isStudent)]
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
        case .verificationConfirmation:
            let isStudent = verificationContext?.isStudent ?? isStudentOnboardingFlow
            return navigationStack(for: .verificationIntro(isStudent: isStudent)) + [.verificationConfirmation]
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
        guard let stored = onboardingStore.loadVerificationMethod() else { return }
        let method: VerificationMethod = stored == "photo_id" ? .photoId : .email
        verificationContext = VerificationContext(isStudent: isStudentOnboardingFlow, method: method)
    }

    func reportRemoteProgressIfNeeded(for screen: AuthScreen) {
        guard let remote = remoteStep(for: screen) else { return }
        guard shouldReportRemoteStep(remote) else { return }
        guard remote != lastReportedRemoteStep else { return }
        lastReportedRemoteStep = remote
        Task {
            await authViewModel.reportOnboardingStep(remote)
        }
    }

    func ensureOnboardingVerificationStepForCommunityEndpoints() async {
        let highestKnown = [lastReportedRemoteStep, authViewModel.onboardingStep]
            .compactMap { $0 }
            .max { lhs, rhs in
                lhs.progressOrder < rhs.progressOrder
            }

        if let highestKnown, highestKnown.progressOrder >= RemoteOnboardingStep.verification.progressOrder {
            return
        }

        if highestKnown == nil || highestKnown == .profileSetup {
            await authViewModel.reportOnboardingStep(.selectCompany)
        }

        await authViewModel.reportOnboardingStep(.verification)
    }

    func shouldReportRemoteStep(_ candidate: RemoteOnboardingStep) -> Bool {
        let highestKnown = [lastReportedRemoteStep, authViewModel.onboardingStep]
            .compactMap { $0 }
            .max { lhs, rhs in
                lhs.progressOrder < rhs.progressOrder
            }

        guard let highestKnown else { return true }
        return candidate.progressOrder >= highestKnown.progressOrder
    }

    func remoteStep(for screen: AuthScreen) -> RemoteOnboardingStep? {
        switch screen {
        case .profileSetup, .verificationInfo:
            return .profileSetup
        case .selectCompany, .selectSchool, .departmentSelection, .degreeSelection:
            return .selectCompany
        case .verificationIntro, .waysToVerifyCompany, .waysToVerifyStudent, .photoIdVerification, .emailVerification, .verificationConfirmation:
            return .verification
        default:
            return nil
        }
    }

    func requiresOrganizationSelection(_ screen: AuthScreen) -> Bool {
        guard authViewModel.selectedOrganization == nil else { return false }
        switch screen {
        case .verificationIntro,
             .waysToVerifyCompany,
             .waysToVerifyStudent,
             .photoIdVerification,
             .emailVerification,
             .verificationConfirmation:
            return true
        default:
            return false
        }
    }
}

private extension RemoteOnboardingStep {
    var progressOrder: Int {
        switch self {
        case .profileSetup:
            return 0
        case .selectCompany:
            return 1
        case .verification:
            return 2
        case .verificationNotifications:
            return 3
        }
    }
}

struct OnboardingRoutingResolver {
    static func resolveScreen(
        remoteStep: RemoteOnboardingStep?,
        localStep: OnboardingStep?,
        isStudent: Bool,
        shouldEnterOnboardingFlow: Bool
    ) -> AuthScreen? {
        if shouldShowVerificationInfoStep(remoteStep: remoteStep, localStep: localStep) {
            return .verificationInfo
        }

        if let remoteStep,
           let remote = AuthScreen.fromRemoteOnboardingStep(remoteStep, isStudent: isStudent) {
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
        default:
            return raw
        }
    }

    private static func shouldShowVerificationInfoStep(
        remoteStep: RemoteOnboardingStep?,
        localStep: OnboardingStep?
    ) -> Bool {
        let shouldGateOnVerificationInfo: Bool
        switch remoteStep {
        case .selectCompany?, .verification?:
            shouldGateOnVerificationInfo = true
        default:
            shouldGateOnVerificationInfo = false
        }

        guard shouldGateOnVerificationInfo else { return false }
        switch localStep {
        case .none, .profileSetup?, .verificationInfo?:
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
