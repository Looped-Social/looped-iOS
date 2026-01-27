import SwiftUI
import Foundation

struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.openURL) private var openURL
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
        #if canImport(FirebaseAuth)
        .sheet(item: $authViewModel.mfaSession) { session in
            TwoFactorChallengeView(authViewModel: authViewModel, session: session)
        }
        #endif
        .onReceive(authViewModel.$isAuthenticated) { isAuthed in
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
        .onAppear {
            if authViewModel.isAuthenticated {
                restoreOnboardingScreen()
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
                    navigate(to: .selectCompany)
                }
            )
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
                            kind: organization.kind
                        )
                    )
                    if let id = organization.backendId {
                        UserDefaults.standard.set(id, forKey: "lastSelectedCommunityId")
                    } else {
                        UserDefaults.standard.removeObject(forKey: "lastSelectedCommunityId")
                    }
                    followCommunityIfPossible(organization.backendId)
                },
                onNavigate: { screen in
                    navigate(to: screen)
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
                            kind: organization.kind
                        )
                    )
                    if let id = organization.backendId {
                        UserDefaults.standard.set(id, forKey: "lastSelectedCommunityId")
                    } else {
                        UserDefaults.standard.removeObject(forKey: "lastSelectedCommunityId")
                    }
                    followCommunityIfPossible(organization.backendId)
                },
                onNavigate: { screen in
                    navigate(to: screen)
                }
            )
        case .departmentSelection:
            OrganizationDetailSelectionView(
                title: "Field",
                kind: .field,
                searchText: $departmentSearchText,
                selectedItem: $selectedDepartment,
                onSelect: { selection in
                    Task {
                        followSpecializationIfPossible(selection.id)
                        navigate(to: .verificationIntro(isStudent: false))
                    }
                }
            )
        case .degreeSelection:
            OrganizationDetailSelectionView(
                title: "Major",
                kind: .major,
                searchText: $degreeSearchText,
                selectedItem: $selectedDegree,
                onSelect: { selection in
                    Task {
                        followSpecializationIfPossible(selection.id)
                        navigate(to: .verificationIntro(isStudent: true))
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
                    VerificationOption(id: "photo_id", title: "Photo With Gov. ID")
                ],
                currentStep: verificationStep(for: .waysToVerifyCompany),
                totalSteps: verificationTotalSteps,
                selectedOptionId: $companyVerificationOptionId,
                onBack: {},
                onContinue: { option in
                    let method = VerificationMethod.from(optionId: option.id)
                    verificationContext = VerificationContext(isStudent: false, method: method)
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
                    VerificationOption(id: "photo_id", title: "Photo With Gov. ID")
                ],
                currentStep: verificationStep(for: .waysToVerifyStudent),
                totalSteps: verificationTotalSteps,
                selectedOptionId: $studentVerificationOptionId,
                onBack: {},
                onContinue: { option in
                    let method = VerificationMethod.from(optionId: option.id)
                    verificationContext = VerificationContext(isStudent: true, method: method)
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
                    }
                    pushIfNeeded(.verificationConfirmation)
                },
                showsHeader: false
            )
        case .verificationConfirmation:
            VerificationConfirmationView(
                authViewModel: authViewModel,
                currentStep: verificationStep(for: .verificationConfirmation),
                totalSteps: verificationTotalSteps,
                onBack: {},
                onSkip: {
                    skipToNotifications()
                },
                onComplete: {
                    navigate(to: .verificationNotifications)
                },
                showsHeader: false
            )
        case .verificationNotifications:
            VerificationNotificationsView(
                loopName: selectedLoopName,
                currentStep: verificationStep(for: .verificationNotifications),
                totalSteps: verificationTotalSteps,
                onBack: {},
                onEnableNotifications: { wantsRecommendations in
                    Task {
                        await authViewModel.enableNotificationsDuringOnboarding(
                            wantsRecommendations: wantsRecommendations
                        )
                        await authViewModel.finishOnboardingFromNotificationsStep()
                    }
                },
                onSkip: {
                    Task {
                        await authViewModel.finishOnboardingFromNotificationsStep()
                    }
                },
                showsHeader: false
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
        verificationFlowMode == .full ? 5 : 1
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
        case .verificationNotifications:
            return 5
        default:
            return 1
        }
    }

    func skipToNotifications() {
        verificationFlowMode = .skipped
        verificationContext = nil
        if let introIndex = path.lastIndex(where: { screen in
            if case .verificationIntro = screen { return true }
            return false
        }) {
            path = Array(path.prefix(introIndex + 1))
        }
        pushIfNeeded(.verificationNotifications)
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

    // Intentionally no "pick communities" step in onboarding; users only choose their org + field/major.
}

enum AuthScreen: Hashable {
    case onboarding
    case profileSetup
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
    case verificationNotifications
    case login
    case signUp
}

private extension AuthView {
    func restoreOnboardingScreen() {
        guard !authViewModel.onboardingComplete else { return }
        restoreOrganizationDraftIfNeeded()
        if let step = onboardingStore.loadProgress(), let restored = AuthScreen.fromOnboardingStep(step) {
            setNavigationStack(for: restored)
        } else if let remote = authViewModel.onboardingStep {
            if remote == .selectCompany, let kind = authViewModel.selectedOrganization?.kind {
                setNavigationStack(for: (kind == .school) ? .degreeSelection : .departmentSelection)
            } else if let restored = AuthScreen.fromRemoteOnboardingStep(remote, isStudent: isStudentOnboardingFlow) {
                setNavigationStack(for: restored)
            }
        } else if authViewModel.shouldEnterOnboardingFlow {
            setNavigationStack(for: .profileSetup)
        }
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
        case .selectCompany:
            return [.profileSetup, .selectCompany]
        case .selectSchool:
            return [.profileSetup, .selectSchool]
        case .departmentSelection:
            return [.profileSetup, .selectCompany, .departmentSelection]
        case .degreeSelection:
            return [.profileSetup, .selectCompany, .degreeSelection]
        case .verificationIntro(let isStudent):
            let base: [AuthScreen] = isStudent
                ? [.profileSetup, .selectCompany, .degreeSelection]
                : [.profileSetup, .selectCompany, .departmentSelection]
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
        case .verificationNotifications:
            let isStudent = verificationContext?.isStudent ?? isStudentOnboardingFlow
            return navigationStack(for: .verificationIntro(isStudent: isStudent))
                + [.verificationConfirmation, .verificationNotifications]
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
            kind: draft.kind
        )
        if selectedLoopName == "Looped" {
            selectedLoopName = draft.name
        }
        if selectedCommunityId == nil {
            selectedCommunityId = draft.backendId
        }
    }

    func reportRemoteProgressIfNeeded(for screen: AuthScreen) {
        guard let remote = remoteStep(for: screen) else { return }
        guard remote != lastReportedRemoteStep else { return }
        lastReportedRemoteStep = remote
        Task {
            await authViewModel.reportOnboardingStep(remote)
        }
    }

    func remoteStep(for screen: AuthScreen) -> RemoteOnboardingStep? {
        switch screen {
        case .profileSetup:
            return .profileSetup
        case .selectCompany, .selectSchool, .departmentSelection, .degreeSelection:
            return .selectCompany
        case .verificationIntro, .waysToVerifyCompany, .waysToVerifyStudent, .photoIdVerification, .emailVerification, .verificationConfirmation:
            return .verification
        default:
            return nil
        }
    }
}

private extension AuthScreen {
    var onboardingStep: OnboardingStep? {
        switch self {
        case .profileSetup:
            return .profileSetup
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
        case .verificationNotifications:
            return .verificationNotifications
        default:
            return nil
        }
    }

    static func fromOnboardingStep(_ step: OnboardingStep) -> AuthScreen? {
        switch step {
        case .profileSetup:
            return .profileSetup
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
            return .verificationNotifications
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
            return .verificationNotifications
        }
    }
}

#Preview {
    AuthView(authViewModel: AuthViewModel())
}
