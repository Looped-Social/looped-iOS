import SwiftUI

private struct FirstPostCongratsSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct FirstPostCongratsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sharePayload: FirstPostCongratsSharePayload?
    let postId: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                LoopedCloseButton(action: {
                    trackDismissed()
                    dismiss()
                })
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.loopedMutedBackground)
                        .frame(width: 76, height: 76)

                    Image(systemName: "sparkles")
                        .font(.loopedSymbol(.semibold, size: 30))
                        .foregroundColor(.loopedPrimary)
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("Congrats on your first post")
                        .font(.loopedHeadingMedium28)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Invite coworkers to join the conversation.")
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    PrimaryButton(title: "Share Looped") {
                        trackShareAttempted()
                        sharePayload = FirstPostCongratsSharePayload(items: [
                            "I just made my first post on Looped — join me!",
                            URL(string: "https://mylooped.app")!
                        ])
                    }

                    SecondaryButton(title: "Not now") {
                        trackDismissed()
                        dismiss()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.loopedBackground)
        .accessibilityIdentifier("firstPostCongratsSheet")
        .onAppear { trackShown() }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items) { completed, _ in
                if completed { trackShareCompleted() }
            }
        }
    }

    private func trackShown() {
        Task {
            await TelemetryManager.shared.track(
                type: .milestoneFirstPostSheetShown,
                postId: postId,
                data: ["milestone_type": .string(FeedViewModel.firstPostEverMilestone)]
            )
        }
    }

    private func trackDismissed() {
        Task {
            await TelemetryManager.shared.track(
                type: .milestoneFirstPostDismissed,
                postId: postId,
                data: ["milestone_type": .string(FeedViewModel.firstPostEverMilestone)]
            )
        }
    }

    private func trackShareAttempted() {
        Task {
            await TelemetryManager.shared.track(
                type: .milestoneFirstPostShareAttempted,
                postId: postId,
                data: ["milestone_type": .string(FeedViewModel.firstPostEverMilestone)]
            )
        }
    }

    private func trackShareCompleted() {
        Task {
            await TelemetryManager.shared.track(
                type: .milestoneFirstPostShareCompleted,
                postId: postId,
                data: ["milestone_type": .string(FeedViewModel.firstPostEverMilestone)]
            )
        }
    }
}

#Preview {
    FirstPostCongratsSheetView(postId: 55)
        .preferredColorScheme(.light)
}
