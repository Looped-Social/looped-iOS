import SwiftUI
import Foundation

struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.openURL) private var openURL
    @State private var currentScreen: AuthScreen = .onboarding
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
        Group {
            switch currentScreen {
            case .onboarding:
                OnboardingView(authViewModel: authViewModel) { screen in
                    currentScreen = screen
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
                    onBack: {
                        currentScreen = .profileSetup
                    },
                    onNavigate: { screen in
                        currentScreen = screen
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
                    onBack: {
                        currentScreen = .profileSetup
                    },
                    onNavigate: { screen in
                        currentScreen = screen
                    }
                )
            case .departmentSelection:
                OrganizationDetailSelectionView(
                    title: "Department",
                    kind: .department,
                    searchText: $departmentSearchText,
                    selectedItem: $selectedDepartment,
                    onSelect: { selection in
                        followCommunityIfPossible(selection.id)
                        currentScreen = .verificationIntro(isStudent: false)
                    },
                    onBack: {
                        currentScreen = .selectCompany
                    }
                )
	            case .degreeSelection:
	                OrganizationDetailSelectionView(
	                    title: "Degree",
	                    kind: .major,
	                    searchText: $degreeSearchText,
	                    selectedItem: $selectedDegree,
	                    onSelect: { selection in
	                        followCommunityIfPossible(selection.id)
	                        currentScreen = .verificationIntro(isStudent: true)
	                    },
	                    onBack: {
	                        currentScreen = .selectSchool
	                    }
	                )
	            case .verificationIntro(let isStudent):
	                VerificationIntroView(
	                    loopName: selectedLoopName,
	                    currentStep: verificationStep(for: .verificationIntro(isStudent: isStudent)),
	                    totalSteps: verificationTotalSteps,
                    onBack: {
                        currentScreen = isStudent ? .degreeSelection : .departmentSelection
                    },
	                    onContinue: {
	                        currentScreen = isStudent ? .waysToVerifyStudent : .waysToVerifyCompany
	                    },
	                    onSkip: skipToNotifications,
	                    onHowItWorks: {
	                        openURL(verificationInfoURL)
	                    }
	                )
            case .waysToVerifyCompany:
                WaysToVerifyView(
                    options: [
                        VerificationOption(id: "photo_id", title: "Photo With Gov. ID"),
                        VerificationOption(id: "company_email", title: "Company Email")
                    ],
                    currentStep: verificationStep(for: .waysToVerifyCompany),
                    totalSteps: verificationTotalSteps,
                    selectedOptionId: $companyVerificationOptionId,
                    onBack: {
                        currentScreen = .verificationIntro(isStudent: false)
                    },
                    onContinue: { option in
                        let method = VerificationMethod.from(optionId: option.id)
                        verificationContext = VerificationContext(isStudent: false, method: method)
                        if method == .photoId {
                            currentScreen = .photoIdVerification(isStudent: false)
                        } else {
                            currentScreen = .emailVerification(isStudent: false)
                        }
                    },
	                    onSkip: {
	                        skipToNotifications()
	                    },
	                    onLearnMore: {
	                        openURL(verificationInfoURL)
	                    }
	                )
            case .waysToVerifyStudent:
                WaysToVerifyView(
                    options: [
                        VerificationOption(id: "photo_id", title: "Photo With Gov. ID"),
                        VerificationOption(id: "student_email", title: "Student Email")
                    ],
                    currentStep: verificationStep(for: .waysToVerifyStudent),
                    totalSteps: verificationTotalSteps,
                    selectedOptionId: $studentVerificationOptionId,
                    onBack: {
                        currentScreen = .verificationIntro(isStudent: true)
                    },
                    onContinue: { option in
                        let method = VerificationMethod.from(optionId: option.id)
                        verificationContext = VerificationContext(isStudent: true, method: method)
                        if method == .photoId {
                            currentScreen = .photoIdVerification(isStudent: true)
                        } else {
                            currentScreen = .emailVerification(isStudent: true)
                        }
                    },
	                    onSkip: {
	                        skipToNotifications()
	                    },
	                    onLearnMore: {
	                        openURL(verificationInfoURL)
	                    }
	                )
            case .verificationConfirmation:
                VerificationConfirmationView(
                    authViewModel: authViewModel,
                    currentStep: verificationStep(for: .verificationConfirmation),
                    totalSteps: verificationTotalSteps,
                    onBack: {
                        guard let context = verificationContext else {
                            currentScreen = .verificationIntro(isStudent: isStudentOnboardingFlow)
                            return
                        }
                        currentScreen = context.method == .photoId
                            ? .photoIdVerification(isStudent: context.isStudent)
                            : .emailVerification(isStudent: context.isStudent)
                    },
                    onSkip: skipToNotifications,
                    onComplete: {
                        currentScreen = .verificationNotifications
                    }
                )
            case .photoIdVerification(let isStudent):
                PhotoIdVerificationView(
                    currentStep: verificationStep(for: .photoIdVerification(isStudent: isStudent)),
                    totalSteps: verificationTotalSteps,
                    onBack: {
                        currentScreen = isStudent ? .waysToVerifyStudent : .waysToVerifyCompany
                    },
                    onSkip: skipToNotifications,
                    onComplete: {
                        if verificationContext == nil {
                            verificationContext = VerificationContext(isStudent: isStudent, method: .photoId)
                        }
                        currentScreen = .verificationConfirmation
                    }
                )
            case .emailVerification(let isStudent):
                EmailVerificationView(
                    communityId: selectedCommunityId,
                    communityName: selectedLoopName,
                    currentStep: verificationStep(for: .emailVerification(isStudent: isStudent)),
                    totalSteps: verificationTotalSteps,
                    onBack: {
                        currentScreen = isStudent ? .waysToVerifyStudent : .waysToVerifyCompany
                    },
                    onSkip: skipToNotifications,
                    onComplete: {
                        if verificationContext == nil {
                            verificationContext = VerificationContext(isStudent: isStudent, method: .email)
                        }
                        currentScreen = .verificationConfirmation
                    }
                )
            case .verificationNotifications:
                VerificationNotificationsView(
                    loopName: selectedLoopName,
                    currentStep: verificationStep(for: .verificationNotifications),
                    totalSteps: verificationTotalSteps,
                    onBack: {
                        if verificationFlowMode == .skipped {
                            currentScreen = .verificationIntro(isStudent: isStudentOnboardingFlow)
                        } else {
                            currentScreen = .verificationConfirmation
                        }
                    },
                    onEnableNotifications: { wantsRecommendations in
                        Task {
                            await authViewModel.enableNotificationsDuringOnboarding(
                                wantsRecommendations: wantsRecommendations
                            )
                            await authViewModel.reportOnboardingStep(.verificationNotifications)
                        }
                    },
                    onSkip: {
                        Task {
                            await authViewModel.reportOnboardingStep(.verificationNotifications)
                        }
                    }
                )
            case .profileSetup:
                ProfileSetupView(
                    authViewModel: authViewModel,
                    onBack: {
                        currentScreen = .onboarding
                    },
                    onContinue: {
                        currentScreen = .selectCompany
                    }
                )
            case .login:
                LoginView(viewModel: authViewModel) {
                    currentScreen = .onboarding
                }
            case .signUp:
                SignUpView(viewModel: authViewModel) {
                    currentScreen = .onboarding
                }
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
        .onChange(of: currentScreen) { _, newValue in
            persistProgress(for: newValue)
            reportRemoteProgressIfNeeded(for: newValue)
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
        currentScreen = .verificationNotifications
    }

    func followCommunityIfPossible(_ communityId: Int?) {
        guard let communityId else { return }
        Task {
            try? await communityService.followCommunity(id: communityId)
        }
    }

    // Intentionally no "pick communities" step in onboarding; users only choose their org + dept/degree.
}

enum AuthScreen: Equatable {
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
            currentScreen = restored
        } else if let remote = authViewModel.onboardingStep {
            if remote == .selectCompany, let kind = authViewModel.selectedOrganization?.kind {
                currentScreen = (kind == .school) ? .degreeSelection : .departmentSelection
            } else if let restored = AuthScreen.fromRemoteOnboardingStep(remote, isStudent: isStudentOnboardingFlow) {
                currentScreen = restored
            }
        } else if authViewModel.shouldEnterOnboardingFlow {
            currentScreen = .profileSetup
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
