import SwiftUI

enum CommunityVerificationCompletion: Equatable {
    case verified
    case submitted
}

struct CommunityVerificationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authViewModel: AuthViewModel
    let community: CommunityProfileData
    let onComplete: (CommunityVerificationCompletion) -> Void

    @State private var path: [VerificationStep] = []
    @State private var selectedOptionId: String?
    private let verificationInfoURL = URL(string: "https://www.mylooped.app/privacy")!

    init(community: CommunityProfileData, onComplete: @escaping (CommunityVerificationCompletion) -> Void) {
        self.community = community
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack(path: $path) {
            content(for: .intro)
                .navigationDestination(for: VerificationStep.self) { step in
                    content(for: step)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func content(for step: VerificationStep) -> some View {
        Group {
            switch step {
            case .intro:
                VerificationIntroView(
                    loopName: community.name,
                    currentStep: 1,
                    totalSteps: 4,
                    onBack: { dismiss() },
                    onContinue: { path.append(.methods) },
                    onHowItWorks: { openURL(verificationInfoURL) },
                    showsHeader: false
                )
            case .methods:
                WaysToVerifyView(
                    options: verificationOptions,
                    currentStep: 2,
                    totalSteps: 4,
                    selectedOptionId: $selectedOptionId,
                    onBack: {},
                    onContinue: { option in
                        selectedOptionId = option.id
                        if option.id == "email" {
                            path.append(.email)
                        } else {
                            path.append(.photoId)
                        }
                    },
                    onSkip: nil,
                    onLearnMore: { openURL(verificationInfoURL) },
                    showsHeader: false
                )
            case .email:
                EmailVerificationView(
                    communityId: community.id,
                    communityName: community.name,
                    currentStep: 3,
                    totalSteps: 4,
                    onBack: {},
                    onComplete: {
                        pushIfNeeded(.confirmation)
                        return true
                    },
                    showsHeader: false
                )
            case .photoId:
                PhotoIdVerificationView(
                    communityId: community.id,
                    currentStep: 3,
                    totalSteps: 4,
                    onBack: {},
                    onComplete: { pushIfNeeded(.confirmation) },
                    showsHeader: false
                )
            case .confirmation:
                if selectedOptionId == "email" {
                    VerificationConfirmationView(
                        authViewModel: authViewModel,
                        currentStep: 4,
                        totalSteps: 4,
                        onBack: {},
                        onSkip: nil,
                        onComplete: handleComplete,
                        showsHeader: false,
                        confirmationKind: .emailVerified(loopName: community.name)
                    )
                } else {
                    VerificationSubmittedView(
                        currentStep: 4,
                        totalSteps: 4,
                        onBack: {},
                        onComplete: handleComplete,
                        showsHeader: false
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
                .tint(.loopedTextSecondary)
                .accessibilityLabel("Close")
            }
        }
    }

    private var verificationOptions: [VerificationOption] {
        let emailTitle = community.kind == .school ? "Student Email" : "Company Email"
        return [
            VerificationOption(id: "email", title: emailTitle),
            VerificationOption(id: "photo_id", title: "Work ID / Work Badge")
        ]
    }

    private func pushIfNeeded(_ step: VerificationStep) {
        guard path.last != step else { return }
        path.append(step)
    }

    private func handleComplete() {
        let completion: CommunityVerificationCompletion = selectedOptionId == "email" ? .verified : .submitted
        onComplete(completion)
        dismiss()
    }

    private enum VerificationStep: Hashable {
        case intro
        case methods
        case email
        case photoId
        case confirmation
    }
}

#Preview {
    CommunityVerificationFlowView(
        community: CommunityProfileData(
            id: 1,
            name: "Finance",
            shortName: nil,
            description: "Talk markets, careers, and everything in finance.",
            kind: .company,
            specializationType: .unknown,
            memberCount: 1_000_000,
            imageUrl: nil,
            isFollowing: false,
            isJoined: false
        ),
        onComplete: { _ in }
    )
    .environmentObject(AuthViewModel())
}
