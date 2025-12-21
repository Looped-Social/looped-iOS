import SwiftUI
import UIKit

struct UserSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    private let userService: UserServiceProtocol = UserService()

    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var emailNotifications = true
    @State private var pushNotifications = true
    @State private var hasLoadedUser = false
    @State private var isSaving = false
    @State private var saveError: String?

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

                    // Full Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Name")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        TextField("Full Name", text: $displayName)
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

                    // Workplace/School Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(organizationLabel) Information")
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            UserSettingsInfoRow(label: organizationLabel, value: currentOrganizationName)
                            Divider().padding(.horizontal, 20)
                            UserSettingsInfoRow(label: "Position", value: currentUserPosition)
                            Divider().padding(.horizontal, 20)
                            UserSettingsInfoRow(label: "Verified", value: currentUserVerified)
                        }
                        .background(Color.loopedTextSecondary.opacity(0.05))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }

                    // Save Button
                    Button(action: saveProfile) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isSaving ? "Saving..." : "Save Changes")
                                .font(.loopedBodyStrong)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSaving ? Color.loopedPrimary.opacity(0.7) : Color.loopedPrimary)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    if let saveError = saveError {
                        Text(saveError)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .onAppear {
            hydrateFromUser()
        }
        .onChange(of: authViewModel.currentUser?.id) { _ in
            hasLoadedUser = false
            hydrateFromUser()
        }
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

private extension UserSettingsView {
    var currentUser: User? { authViewModel.currentUser }
    var currentUserCompany: String { currentUser?.company ?? "Looped" }
    var currentOrganizationName: String { authViewModel.selectedOrganization?.name ?? currentUserCompany }
    var organizationKind: OrganizationKind { authViewModel.selectedOrganization?.kind ?? .company }
    var organizationLabel: String { organizationKind == .school ? "School" : "Workplace" }
    var currentUserPosition: String { organizationKind == .school ? "Student" : "Team Member" }
    var currentUserVerified: String { currentUser?.isVerified == true ? "Yes" : "No" }

    func hydrateFromUser() {
        guard let user = currentUser, !hasLoadedUser else { return }
        username = user.username ?? user.handle
        displayName = user.displayName ?? user.handle
        bio = user.bio ?? ""
        hasLoadedUser = true
    }

    func saveProfile() {
        guard !isSaving else { return }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        saveError = nil
        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                _ = try await userService.updateProfile(
                    displayName: displayName,
                    bio: bio.isEmpty ? nil : bio,
                    isAnonymous: false,
                    showFollowerCount: nil
                )
                await authViewModel.loadCurrentUser()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
}

#Preview {
    UserSettingsView()
        .environmentObject(AuthViewModel())
}
