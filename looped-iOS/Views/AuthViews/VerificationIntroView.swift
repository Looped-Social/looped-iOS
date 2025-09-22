import SwiftUI

struct VerificationIntroView: View {
    let isStudent: Bool
    let onNavigate: (AuthScreen) -> Void

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

                // Verification illustration
                Image("teal-verify")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: geometry.size.height * 0.35)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)

                // Title and subtitle
                VStack(spacing: 16) {
                    Text("We're Built On Truth")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)
                        .fontWeight(.semibold)

                    VStack(spacing: 4) {
                        Text("thats why all posts")
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextSecondary)
                        Text("are from verified accounts")
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                .padding(.bottom, 50)

                // Verify button
                Button(action: {
                    onNavigate(isStudent ? .waysToVerifyStudent : .waysToVerifyCompany)
                }) {
                    Text("Verify")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.loopedPrimary)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Verify later link
                VStack(spacing: 8) {
                    Text("Don't have anything to say?")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)

                    Button("Verify Later") {
                        onNavigate(.signUp)
                    }
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedPrimary)
                }
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    VerificationIntroView(isStudent: false) { _ in }
}
