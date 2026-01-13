import SwiftUI

struct CommunityVerificationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let community: CommunityProfileData
    let onComplete: () -> Void

    @State private var step: VerificationStep = .intro
    @State private var selectedOptionId: String?
    private let verificationInfoURL = URL(string: "https://www.mylooped.app/privacy")!

    init(community: CommunityProfileData, onComplete: @escaping () -> Void) {
        self.community = community
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.loopedCustom(.semibold, size: 16))
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.loopedMutedBackground)
                    .clipShape(Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .intro:
            VerificationIntroView(
                loopName: community.name,
                currentStep: 1,
                totalSteps: 4,
                onBack: { dismiss() },
                onContinue: { step = .methods },
                onHowItWorks: { openURL(verificationInfoURL) }
            )
        case .methods:
            WaysToVerifyView(
                options: verificationOptions,
                currentStep: 2,
                totalSteps: 4,
                selectedOptionId: $selectedOptionId,
                onBack: { step = .intro },
                onContinue: { option in
                    if option.id == "email" {
                        step = .email
                    } else {
                        step = .photoId
                    }
                },
                onSkip: nil,
                onLearnMore: { openURL(verificationInfoURL) }
            )
        case .email:
            EmailVerificationView(
                communityId: community.id,
                communityName: community.name,
                currentStep: 3,
                totalSteps: 4,
                onBack: { step = .methods },
                onComplete: { step = .confirmation }
            )
        case .photoId:
            PhotoIdVerificationView(
                communityId: community.id,
                currentStep: 3,
                totalSteps: 4,
                onBack: { step = .methods },
                onComplete: { step = .confirmation }
            )
        case .confirmation:
            VerificationSubmittedView(
                currentStep: 4,
                totalSteps: 4,
                onBack: { step = selectedOptionId == "email" ? .email : .photoId },
                onComplete: handleComplete
            )
        }
    }

    private var verificationOptions: [VerificationOption] {
        let emailTitle = community.kind == .school ? "Student Email" : "Company Email"
        return [
            VerificationOption(id: "photo_id", title: "Photo With Gov. ID"),
            VerificationOption(id: "email", title: emailTitle)
        ]
    }

    private func handleComplete() {
        onComplete()
        dismiss()
    }

    private enum VerificationStep {
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
            description: "Talk markets, careers, and everything in finance.",
            kind: .company,
            specializationType: .unknown,
            memberCount: 1_000_000,
            imageUrl: nil,
            isFollowing: false,
            isJoined: false
        ),
        onComplete: {}
    )
}
