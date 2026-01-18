import SwiftUI

struct AccountActionIntroView: View {
    let action: AccountActionKind
    @Environment(\.dismiss) private var dismiss

    private let feedbackURL = URL(string: "https://mylooped.app/feedback")!

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(headline)
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(subheadline)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(detailText)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)

                        if showsFeedbackLink {
                            Link("Provide feedback here", destination: feedbackURL)
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedSecondary)
                        }
                    }
                    .padding(16)
                    .background(Color.loopedTextSecondary.opacity(0.08))
                    .cornerRadius(12)

                    NavigationLink(destination: AccountActionConfirmView(action: action)) {
                        Text(actionButtonTitle)
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.loopedPrimary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack {
            LoopedBackButton(action: { dismiss() })

            Spacer()

            Text(title)
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            LoopedBackButton(action: {})
                .opacity(0)
                .disabled(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }

    private var title: String {
        switch action {
        case .delete:
            return "Delete Account"
        case .deactivate:
            return "Deactivate Account"
        }
    }

    private var headline: String {
        switch action {
        case .delete:
            return "Sorry to see you go"
        case .deactivate:
            return "Need a break?"
        }
    }

    private var subheadline: String {
        switch action {
        case .delete:
            return "Are you sure you want to delete your account?"
        case .deactivate:
            return "Deactivation is a reversible pause."
        }
    }

    private var detailText: String {
        switch action {
        case .delete:
            return "This will delete both your regular account and your anonymous profile."
        case .deactivate:
            return "Your profile is hidden, you will not show in search or feed, and you will not receive notifications. Log back in to reactivate. If you do not reactivate within 90 days, your account will be deleted."
        }
    }

    private var actionButtonTitle: String {
        switch action {
        case .delete:
            return "Yes, delete my account"
        case .deactivate:
            return "Yes, deactivate my account"
        }
    }

    private var showsFeedbackLink: Bool {
        action == .delete
    }
}

struct DeleteAccountIntroView: View {
    var body: some View {
        AccountActionIntroView(action: .delete)
    }
}

struct DeactivateAccountIntroView: View {
    var body: some View {
        AccountActionIntroView(action: .deactivate)
    }
}

#Preview {
    AccountActionIntroView(action: .delete)
}
