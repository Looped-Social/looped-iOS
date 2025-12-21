import SwiftUI

struct DeleteAccountIntroView: View {
    @Environment(\.dismiss) private var dismiss

    private let feedbackURL = URL(string: "https://mylooped.app/feedback")!

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Sorry to see you go")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text("Are you sure you want to delete your account?")
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("This will delete both your regular account and your anonymous profile.")
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)

                        Link("Provide feedback here", destination: feedbackURL)
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedSecondary)
                    }
                    .padding(16)
                    .background(Color.loopedTextSecondary.opacity(0.08))
                    .cornerRadius(12)

                    NavigationLink(destination: DeleteAccountConfirmView()) {
                        Text("Yes, delete my account")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.white)
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
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            Text("Delete Account")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Image(systemName: "chevron.left")
                .font(.system(size: 24, weight: .medium))
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }
}

#Preview {
    DeleteAccountIntroView()
}
