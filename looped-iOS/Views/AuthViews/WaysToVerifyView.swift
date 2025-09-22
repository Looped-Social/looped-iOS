import SwiftUI

struct WaysToVerifyView: View {
    let emailButtonText: String
    let onNavigate: (AuthScreen) -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                    .frame(height: geometry.size.height * 0.08)

                // Title
                Text("Ways to Verify")
                    .font(.loopedHeading)
                    .foregroundColor(.loopedTextPrimary)
                    .padding(.bottom, 40)

                // Main content with rocket and buttons
                HStack(alignment: .center, spacing: 0) {
                    // Rocket illustration on the left
                    VStack {
                        Spacer()
                        Image("rocket-verify")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: geometry.size.height * 0.55)
                        Spacer()
                    }
                    .frame(width: geometry.size.width * 0.4)

                    // Verification buttons on the right
                    VStack(spacing: 32) {
                        Spacer()

                        // Email verification button (Company email or Student email)
                        Button(action: {
                            onNavigate(.verificationConfirmation)
                        }) {
                            Text(emailButtonText)
                                .font(.loopedBodyMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(red: 0.4, green: 0.7, blue: 0.6)) // Teal color
                                .cornerRadius(28)
                        }

                        // Video Verification button
                        Button(action: {
                            onNavigate(.verificationConfirmation)
                        }) {
                            Text("Video Verification")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(red: 0.4, green: 0.7, blue: 0.6)) // Teal color
                                .cornerRadius(28)
                        }

                        // Selfie W/ ID button
                        Button(action: {
                            onNavigate(.verificationConfirmation)
                        }) {
                            Text("Selfie W/ ID")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(red: 0.4, green: 0.7, blue: 0.6)) // Teal color
                                .cornerRadius(28)
                        }

                        Spacer()
                    }
                    .frame(width: geometry.size.width * 0.6)
                    .padding(.trailing, 32)
                }

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
    WaysToVerifyView(emailButtonText: "Company email") { _ in }
}