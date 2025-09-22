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
                    Text("Nice to meet you")
                        .font(.loopedHeading)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("are you currently...")
                        .font(.loopedHeading)
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
                            .font(.loopedBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.loopedPrimary)
                            .cornerRadius(28)
                    }
                    .padding(.horizontal, 32)

                    // "or" divider
                    Text("or")
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.vertical, 8)

                    // Student button
                    Button(action: {
                        onNavigate(.selectSchool)
                    }) {
                        Text("Student")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 0.4, green: 0.7, blue: 0.6)) // Teal color
                            .cornerRadius(28)
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Skip for now link
                Button("Skip For Now") {
                    onNavigate(.signUp)
                }
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedPrimary)
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    EmploymentStatusView { _ in }
}