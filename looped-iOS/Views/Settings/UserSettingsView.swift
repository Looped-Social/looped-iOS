import SwiftUI

struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var username = "@johndoe"
    @State private var displayName = "John Doe"
    @State private var bio = "Software engineer at JP Morgan"
    @State private var emailNotifications = true
    @State private var pushNotifications = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                Text("User Settings")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                // Invisible button for symmetry
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 12)

            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Picture Section
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.loopedTextSecondary)

                        Button("Change Profile Picture") {
                            // TODO: Implement photo picker
                        }
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedSecondary)
                    }
                    .padding(.top, 20)

                    // Username Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        TextField("Username", text: $username)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .padding(12)
                            .background(Color.loopedTextSecondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)

                    // Display Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        TextField("Display Name", text: $displayName)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .padding(12)
                            .background(Color.loopedTextSecondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)

                    // Bio Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        TextEditor(text: $bio)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.loopedTextSecondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)

                    // Workplace Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workplace Information")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            UserSettingsInfoRow(label: "Company", value: "JP Morgan Chase")
                            Divider().padding(.horizontal, 20)
                            UserSettingsInfoRow(label: "Position", value: "Software Engineer")
                            Divider().padding(.horizontal, 20)
                            UserSettingsInfoRow(label: "Verified", value: "Yes")
                        }
                        .background(Color.loopedTextSecondary.opacity(0.05))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }

                    // Save Button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        // TODO: Implement save functionality
                    }) {
                        Text("Save Changes")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.loopedPrimary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

struct UserSettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            Spacer()

            Text(value)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

#Preview {
    UserSettingsView()
}
