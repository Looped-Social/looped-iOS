import SwiftUI
import Foundation

struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var currentScreen: AuthScreen = .onboarding
    @State private var selectedLoopName: String = "Looped"
    private let onboardingStore = OnboardingProgressStore()

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
                    organizations: MockOrganizations.companies + MockOrganizations.schools,
                    onSelect: { organization in
                        authViewModel.selectedOrganization = organization
                    }
                ) { screen in
                    currentScreen = screen
                }
            case .selectSchool:
                OrganizationSelectionView(
                    title: "Select your school",
                    organizations: MockOrganizations.schools,
                    onSelect: { organization in
                        authViewModel.selectedOrganization = organization
                    }
                ) { screen in
                    currentScreen = screen
                }
            case .communitySelection(let isStudent):
                CommunitySelectionView(communities: MockSearchContent.communities) { selected in
                    if let first = selected.first {
                        selectedLoopName = first.name
                        if let backendId = first.backendId {
                            UserDefaults.standard.set(backendId, forKey: "lastSelectedCommunityId")
                        }
                    }
                    if selected.isEmpty {
                        authViewModel.onboardingComplete = true
                    } else {
                        currentScreen = .verificationIntro(isStudent: isStudent)
                    }
                }
            case .departmentSelection:
                OrganizationDetailSelectionView(
                    title: "Department",
                    items: MockOnboardingDetails.departments
                ) { _ in
                    currentScreen = .communitySelection(isStudent: false)
                }
            case .degreeSelection:
                OrganizationDetailSelectionView(
                    title: "Degree",
                    items: MockOnboardingDetails.degrees
                ) { _ in
                    currentScreen = .communitySelection(isStudent: true)
                }
            case .verificationIntro(let isStudent):
                VerificationIntroView(
                    loopName: selectedLoopName,
                    currentStep: 1,
                    totalSteps: 5,
                    onBack: {
                        currentScreen = .communitySelection(isStudent: isStudent)
                    },
                    onContinue: {
                        currentScreen = isStudent ? .waysToVerifyStudent : .waysToVerifyCompany
                    },
                    onHowItWorks: {
                        // TODO: Wire up "How Verification Works" content.
                    }
                )
            case .waysToVerifyCompany:
                WaysToVerifyView(
                    options: [
                        VerificationOption(id: "photo_id", title: "Photo With Gov. ID"),
                        VerificationOption(id: "company_email", title: "Company Email")
                    ],
                    currentStep: 2,
                    totalSteps: 5,
                    onBack: {
                        currentScreen = .verificationIntro(isStudent: false)
                    },
                    onContinue: { option in
                        if option.id == "photo_id" {
                            currentScreen = .photoIdVerification(isStudent: false)
                        } else {
                            currentScreen = .emailVerification(isStudent: false)
                        }
                    },
                    onSkip: {
                        currentScreen = .verificationConfirmation
                    },
                    onLearnMore: {
                        // TODO: Wire up "learn more" to verification info page.
                    }
                )
            case .waysToVerifyStudent:
                WaysToVerifyView(
                    options: [
                        VerificationOption(id: "photo_id", title: "Photo With Gov. ID"),
                        VerificationOption(id: "student_email", title: "Student Email")
                    ],
                    currentStep: 2,
                    totalSteps: 5,
                    onBack: {
                        currentScreen = .verificationIntro(isStudent: true)
                    },
                    onContinue: { option in
                        if option.id == "photo_id" {
                            currentScreen = .photoIdVerification(isStudent: true)
                        } else {
                            currentScreen = .emailVerification(isStudent: true)
                        }
                    },
                    onSkip: {
                        currentScreen = .verificationConfirmation
                    },
                    onLearnMore: {
                        // TODO: Wire up "learn more" to verification info page.
                    }
                )
            case .verificationConfirmation:
                VerificationConfirmationView(
                    authViewModel: authViewModel,
                    currentStep: 4,
                    totalSteps: 5,
                    onComplete: {
                        currentScreen = .verificationNotifications
                    }
                )
            case .photoIdVerification(let isStudent):
                PhotoIdVerificationView(
                    currentStep: 3,
                    totalSteps: 5,
                    onBack: {
                        currentScreen = isStudent ? .waysToVerifyStudent : .waysToVerifyCompany
                    },
                    onComplete: {
                        currentScreen = .verificationConfirmation
                    }
                )
            case .emailVerification(let isStudent):
                EmailVerificationView(
                    currentStep: 3,
                    totalSteps: 5,
                    onBack: {
                        currentScreen = isStudent ? .waysToVerifyStudent : .waysToVerifyCompany
                    },
                    onContinue: {
                        currentScreen = .verificationConfirmation
                    },
                    onResend: {
                        // TODO: Wire resend email verification.
                    }
                )
            case .verificationNotifications:
                VerificationNotificationsView(
                    loopName: selectedLoopName,
                    currentStep: 5,
                    totalSteps: 5,
                    onEnableNotifications: { wantsRecommendations in
                        Task { @MainActor in
                            await authViewModel.enableNotificationsDuringOnboarding(
                                wantsRecommendations: wantsRecommendations
                            )
                            authViewModel.onboardingComplete = true
                        }
                    },
                    onSkip: {
                        authViewModel.onboardingComplete = true
                    }
                )
            case .profileSetup:
                ProfileSetupView(authViewModel: authViewModel) {
                    currentScreen = .selectCompany
                }
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

enum AuthScreen: Equatable {
    case onboarding
    case profileSetup
    case selectCompany
    case selectSchool
    case departmentSelection
    case degreeSelection
    case communitySelection(isStudent: Bool)
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
        if let step = onboardingStore.loadProgress(), let restored = AuthScreen.fromOnboardingStep(step) {
            currentScreen = restored
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
        case .communitySelection(let isStudent):
            return isStudent ? .communitySelectionStudent : .communitySelectionCompany
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
            return .communitySelection(isStudent: true)
        case .communitySelectionCompany:
            return .communitySelection(isStudent: false)
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
}

#Preview {
    AuthView(authViewModel: AuthViewModel())
}
