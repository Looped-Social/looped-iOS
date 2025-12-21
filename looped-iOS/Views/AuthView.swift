import SwiftUI

struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var currentScreen: AuthScreen = .onboarding
    @State private var selectedLoopName: String = "Looped"

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
                    }
                    if selected.isEmpty {
                        authViewModel.onboardingComplete = true
                    } else {
                        currentScreen = .verificationIntro(isStudent: isStudent)
                    }
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
                    onContinue: { _ in
                        currentScreen = .verificationConfirmation
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
                    onContinue: { _ in
                        currentScreen = .verificationConfirmation
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
            case .verificationNotifications:
                VerificationNotificationsView(
                    loopName: selectedLoopName,
                    currentStep: 5,
                    totalSteps: 5,
                    onEnableNotifications: { _ in
                        authViewModel.onboardingComplete = true
                    },
                    onSkip: {
                        authViewModel.onboardingComplete = true
                    }
                )
            case .profileSetup:
                ProfileSetupView { _ in
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
        .onReceive(authViewModel.$isAuthenticated) { isAuthed in
            if isAuthed && !authViewModel.onboardingComplete && authViewModel.shouldEnterOnboardingFlow {
                currentScreen = .profileSetup
            }
        }
        .onAppear {
            if authViewModel.isAuthenticated && !authViewModel.onboardingComplete && authViewModel.shouldEnterOnboardingFlow {
                currentScreen = .profileSetup
            }
        }
    }
}

enum AuthScreen {
    case onboarding
    case profileSetup
    case selectCompany
    case selectSchool
    case communitySelection(isStudent: Bool)
    case verificationIntro(isStudent: Bool)
    case waysToVerifyCompany
    case waysToVerifyStudent
    case verificationConfirmation
    case verificationNotifications
    case login
    case signUp
}

#Preview {
    AuthView(authViewModel: AuthViewModel())
}
