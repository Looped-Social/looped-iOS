import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var isSaving = false
    @State private var showSuccessMessage = false

    var body: some View {
        if viewModel.user == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.loopedBackground.ignoresSafeArea())
        } else {
            VStack(spacing: 0) {
                // Header
                EditProfileHeader {
                    dismiss()
                }

                // Scrollable content
                ScrollView {
                VStack(spacing: 24) {
                    // Profile Image Section
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                // Profile Image
                                if let profileImage = profileImage {
                                    profileImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    AsyncImage(url: URL(string: viewModel.user?.profileImageURL ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.loopedTextSecondary.opacity(0.1))
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.loopedTextSecondary)
                                            )
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                }

                                // Edit icon overlay
                                Circle()
                                    .fill(Color.loopedPrimary)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        .onChange(of: selectedImage) { oldValue, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    profileImage = Image(uiImage: uiImage)
                                }
                            }
                        }

                        Text("Tap to change profile photo")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                    }
                    .padding(.top, 24)

                    // Form Fields
                    VStack(spacing: 20) {
                        // Display Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            TextField("Enter your display name", text: $displayName)
                                .font(.loopedBody)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(12)
                        }

                        // Bio
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            ZStack(alignment: .topLeading) {
                                if bio.isEmpty {
                                    Text("Tell us about yourself...")
                                        .font(.loopedBody)
                                        .foregroundColor(.loopedTextSecondary.opacity(0.5))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 18)
                                }

                                TextEditor(text: $bio)
                                    .font(.loopedBody)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(minHeight: 120)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.white)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(12)

                            Text("\(bio.count)/150")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        // Handle (read-only)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Handle")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            HStack {
                                Text("@\(viewModel.user?.handle ?? "")")
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedTextSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)

                                Spacer()
                            }
                            .background(Color.loopedTextSecondary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(12)

                            Text("Your handle cannot be changed")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }

                        // Company & Job Title (read-only)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Company")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            HStack {
                                Text(viewModel.user?.company ?? "")
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedTextSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)

                                Spacer()
                            }
                            .background(Color.loopedTextSecondary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(12)

                            Text("To change your company, contact support")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Success Message
                    if showSuccessMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Profile updated successfully")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }

                    // Error Message
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }

                    // Save Button
                    PrimaryButton(
                        title: "Save Changes",
                        isEnabled: !displayName.isEmpty && bio.count <= 150,
                        isLoading: isSaving
                    ) {
                        Task {
                            await saveProfile()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                // Initialize with current user data
                displayName = viewModel.user?.displayName ?? ""
                bio = viewModel.user?.bio ?? ""
            }
        }
    }

    private func saveProfile() async {
        isSaving = true
        showSuccessMessage = false

        await viewModel.updateProfile(
            displayName: displayName.isEmpty ? nil : displayName,
            bio: bio.isEmpty ? nil : bio,
            isAnonymous: viewModel.user?.isAnonymous ?? false
        )

        isSaving = false

        if viewModel.errorMessage == nil {
            showSuccessMessage = true

            // Dismiss after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
}

// MARK: - Edit Profile Header

struct EditProfileHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
            }

            HStack(spacing: 2) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 24)

                Text("ooped")
                    .font(.loopedBody24)
                    .foregroundColor(.loopedContrast)
            }

            Spacer()

            Text("Edit Profile")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }
}

#Preview {
    EditProfileView(viewModel: ProfileViewModel())
}
