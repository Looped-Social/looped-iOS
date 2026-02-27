import SwiftUI

private struct FirstPostCongratsSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct FirstPostCongratsSheetView: View {
    @State private var sharePayload: FirstPostCongratsSharePayload?
    let postId: Int?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Image("first-post")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 208, height: 208)
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("First post down. Time to spark a conversation.")
                        .font(.loopedSubheadSemibold)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Share it with someone you know.")
                        .font(.loopedSubheadlineScaled)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    PrimaryButton(title: "Share post") {
                        trackShareAttempted()
                        sharePayload = FirstPostCongratsSharePayload(items: shareItems)
                    }

                    LoopedCancelTextButton(
                        action: onDismiss,
                        title: "Dismiss",
                        foregroundColor: .loopedTextSecondary
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 360, alignment: .top)
        .background(Color.loopedBackground)
        .accessibilityIdentifier("firstPostCongratsSheet")
        .onAppear { trackShown() }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items) { completed, _ in
                if completed { trackShareCompleted() }
            }
        }
    }

    private var shareItems: [Any] {
        let shareUrl: URL
        if let postId {
            shareUrl = URL(string: "https://mylooped.app/p/\(postId)")!
        } else {
            shareUrl = URL(string: "https://mylooped.app")!
        }
        return [
            "First post down. Time to spark a conversation.",
            shareUrl
        ]
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
    FirstPostCongratsSheetView(postId: 55, onDismiss: {})
        .preferredColorScheme(.light)
}
