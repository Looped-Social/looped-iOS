import SwiftUI

struct VerificationConfirmationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                    .frame(height: geometry.size.height * 0.08)

                // Logo
                HStack(spacing: 2) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 32)

                    Text("ooped")
                        .font(.loopedLogo)
                        .foregroundColor(.loopedTextPrimary)
                }
                .padding(.bottom, 40)

                // Confirmation illustration
                Image("confirm-verify")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: geometry.size.height * 0.35)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)

                // Title and message
                VStack(spacing: 16) {
                    Text("Thanks for submitting!")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)
                        .fontWeight(.semibold)

                    VStack(spacing: 4) {
                        Text("Give us 24 Hours to process your verification,")
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextSecondary)
                            .multilineTextAlignment(.center)
                        Text("you're on your way to your first loop!")
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)

                // Continue button
                Button(action: {
                    onComplete()
                }) {
                    Text("Continue")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.loopedPrimary)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 32)
                .disabled(authViewModel.isLoading)

                Spacer()

            }
        }
    }
}

#Preview {
    VerificationConfirmationView(authViewModel: AuthViewModel(), onComplete: { })
}
