import SwiftUI

struct ProfileSetupView: View {
    let onContinue: (ProfileSetupData) -> Void

    @State private var username = ""
    @State private var fullName = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                ScrollView {
                    VStack(spacing: 20) {
                        Text("Create your profile")
                            .font(.loopedHeading)
                            .foregroundColor(.loopedTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Choose a username and tell us a little about you.")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 16) {
                            inputField(title: "Username", placeholder: "looped handle", text: $username, keyboard: .default)
                            inputField(title: "Full Name", placeholder: "First and last name", text: $fullName, keyboard: .default)
                            dateField(title: "Date of Birth", date: $dateOfBirth)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)

                        Button(action: handleContinue) {
                            Text("Continue")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(isFormValid ? Color.loopedPrimary : Color.loopedTextSecondary.opacity(0.3))
                                .cornerRadius(14)
                        }
                        .disabled(!isFormValid)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleContinue() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = ProfileSetupData(username: trimmedUsername, fullName: trimmedName, dateOfBirth: dateOfBirth)
        onContinue(data)
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            TextField(placeholder, text: text)
                .font(.loopedBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.none)
        }
    }

    private func dateField(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            DatePicker("", selection: date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)
        }
    }
}

struct ProfileSetupData {
    let username: String
    let fullName: String
    let dateOfBirth: Date
}

#Preview {
    ProfileSetupView(onContinue: { _ in })
}
