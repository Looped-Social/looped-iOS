import SwiftUI

struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var currentScreen: AuthScreen = .onboarding

    var body: some View {
        Group {
            switch currentScreen {
            case .onboarding:
                OnboardingView(authViewModel: authViewModel) { screen in
                    currentScreen = screen
                }
            case .selectCompany:
                OrganizationSelectionView(
                    title: "Where do you work?",
                    organizations: MockOrganizations.companies
                ) { screen in
                    currentScreen = screen
                }
            case .selectSchool:
                OrganizationSelectionView(
                    title: "Select your school",
                    organizations: MockOrganizations.schools
                ) { screen in
                    currentScreen = screen
                }
            case .verificationIntro(let isStudent):
                VerificationIntroView(isStudent: isStudent) { screen in
                    currentScreen = screen
                }
            case .waysToVerifyCompany:
                WaysToVerifyView(
                    emailButtonText: "Company email"
                ) { screen in
                    currentScreen = screen
                }
            case .waysToVerifyStudent:
                WaysToVerifyView(
                    emailButtonText: "Student email"
                ) { screen in
                    currentScreen = screen
                }
            case .verificationConfirmation:
                VerificationConfirmationView(
                    authViewModel: authViewModel,
                    onComplete: {
                        authViewModel.onboardingComplete = true
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
        .onReceive(authViewModel.$isAuthenticated) { isAuthed in
            if isAuthed && !authViewModel.onboardingComplete {
                currentScreen = .selectCompany
            }
        }
        .onAppear {
            if authViewModel.isAuthenticated && !authViewModel.onboardingComplete {
                currentScreen = .selectCompany
            }
        }
    }
}

enum AuthScreen {
    case onboarding
    case selectCompany
    case selectSchool
    case verificationIntro(isStudent: Bool)
    case waysToVerifyCompany
    case waysToVerifyStudent
    case verificationConfirmation
    case login
    case signUp
}

#Preview {
    AuthView(authViewModel: AuthViewModel())
}
