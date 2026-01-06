import SwiftUI

struct CommunityVerificationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    let community: CommunityProfileData
    let onComplete: () -> Void

    @State private var step: VerificationStep = .intro
    @State private var selectedOptionId: String?

    init(community: CommunityProfileData, onComplete: @escaping () -> Void) {
        self.community = community
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
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
                totalSteps: 1,
                onBack: { dismiss() },
                onContinue: { step = .methods },
                onHowItWorks: {}
            )
        case .methods:
            WaysToVerifyView(
                options: verificationOptions,
                currentStep: 1,
                totalSteps: 1,
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
                onLearnMore: {}
            )
        case .email:
            EmailVerificationView(
                communityId: community.id,
                communityName: community.name,
                currentStep: 1,
                totalSteps: 1,
                onBack: { step = .methods },
                onComplete: handleComplete
            )
        case .photoId:
            PhotoIdVerificationView(
                currentStep: 1,
                totalSteps: 1,
                onBack: { step = .methods },
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
            isFollowing: false
        ),
        onComplete: {}
    )
}
