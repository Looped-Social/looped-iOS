import SwiftUI

struct EmploymentStatusView: View {
    let onNavigate: (AuthScreen) -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                    .frame(height: geometry.size.height * 0.12)

                // Title and subtitle
                VStack(spacing: 12) {
                    Text("Nice to meet you!")
                        .font(.loopedHeadingMedium32)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Are you currently...")
                        .font(.loopedHeadingMedium32)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 80)

                // Employment status buttons
                VStack(spacing: 24) {
                    // Employeed button
                    Button(action: {
                        onNavigate(.selectCompany)
                    }) {
                        Text("Employeed")
                            .font(.loopedHeadingMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .background(Color.loopedPrimary)
                            .cornerRadius(96)
                    }
                    .padding(.horizontal, 32)

                    Text("or")
                        .font(.loopedBody24)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(.vertical, 8)

                    Button(action: {
                        onNavigate(.selectSchool)
                    }) {
                        Text("Student")
                            .font(.loopedHeadingMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            .background(Color.loopedSecondary)
                            .cornerRadius(96)
                    }
                    .padding(.horizontal, 32)
                }

                Button("Skip For Now") {
                    onNavigate(.signUp)
                }
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedSecondary)
                .padding(.bottom, 52)
                .padding(.top, 56)
            }
        }
    }
}

#Preview {
    EmploymentStatusView { _ in }
}
