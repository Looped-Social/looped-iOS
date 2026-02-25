import PhotosUI
import SwiftUI
import UIKit

struct FinishProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = FinishProfileSetupViewModel()
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var pendingCropImage: UIImage?
    @State private var isShowingImageCropper = false
    @State private var isSubmittingSkip = false
    @State private var skipErrorMessage: String?

    var body: some View {
        let profilePhotoPreviewSnapshot = viewModel.profilePhotoPreview
        let currentUserProfileImageURL = authViewModel.currentUser?.profileImageURL

        ScrollView {
            VStack(spacing: 20) {
                header
                photoSection(
                    profilePhotoPreviewSnapshot: profilePhotoPreviewSnapshot,
                    currentUserProfileImageURL: currentUserProfileImageURL
                )
                bioSection
                statusSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .interactiveDismissDisabled(isSubmittingSkip || viewModel.isSaving)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color.loopedBackground)
        }
        .onAppear {
            viewModel.hydrateIfNeeded(user: authViewModel.currentUser)
        }
        .onChange(of: authViewModel.currentUser?.backendId) { _, _ in
            viewModel.hydrateIfNeeded(user: authViewModel.currentUser)
        }
        .onChange(of: selectedProfilePhoto) { _, newValue in
            Task { await handleProfilePhotoSelection(newValue) }
        }
        .sheet(isPresented: $isShowingImageCropper) {
            if let pendingCropImage {
                ProfileImageCropperView(
                    image: pendingCropImage,
                    onCancel: {
                        isShowingImageCropper = false
                        self.pendingCropImage = nil
                        selectedProfilePhoto = nil
                    },
                    onConfirm: { cropped in
                        let prepared = cropped.normalizedOrientation().resized(maxDimension: 1024)
                        viewModel.setSelectedPhotoImage(prepared)
                        isShowingImageCropper = false
                        self.pendingCropImage = nil
                    }
                )
            } else {
                EmptyView()
            }
        }
    }
}

private extension FinishProfileSetupView {
    var header: some View {
        Text("Finish setting up your profile")
            .font(.loopedHeadingMedium32)
            .foregroundColor(.loopedTextPrimary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    func photoSection(
        profilePhotoPreviewSnapshot: UIImage?,
        currentUserProfileImageURL: String?
    ) -> some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let profilePhotoPreview = profilePhotoPreviewSnapshot {
                                Image(uiImage: profilePhotoPreview)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                            } else {
                                ProfileAvatarView(
                                    imageURL: currentUserProfileImageURL,
                                    size: 96,
                                    iconScale: 0.4
                                )
                            }
                        }

                        Circle()
                            .fill(Color.loopedPrimary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.loopedCustom(size: 14))
                                    .foregroundColor(.loopedWhite)
                            )
                    }

                    Text("Tap to change profile photo")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedSecondary)
                }
            }
            .buttonStyle(.plain)

            if profilePhotoPreviewSnapshot != nil {
                Button("Remove selected photo") {
                    selectedProfilePhoto = nil
                    viewModel.clearSelectedPhoto()
                }
                .font(.loopedSmallText)
                .foregroundColor(.loopedSecondary)
                .buttonStyle(.plain)
            }
        }
    }

    var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bio")
                    .font(.loopedBodyStrong)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                Text("\(viewModel.bioRemainingCharacters) characters left")
                    .font(.loopedSmallText)
                    .foregroundColor(viewModel.bioRemainingCharacters < 20 ? .loopedError : .loopedTextSecondary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.bio)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(8)

                if viewModel.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Tell people a bit about you")
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
            }
            .frame(minHeight: 120)
            .background(Color.loopedMutedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    var statusSection: some View {
        if let statusMessage = viewModel.statusMessage, !statusMessage.isEmpty {
            Text(statusMessage)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedSuccess)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let errorMessage = combinedErrorMessage, !errorMessage.isEmpty {
            Text(errorMessage)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedError)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var actionBar: some View {
        VStack(spacing: 12) {
            PrimaryButton(
                title: "Continue",
                isEnabled: !viewModel.isSaving && !isSubmittingSkip,
                isLoading: viewModel.isSaving
            ) {
                Task { await saveProfileChanges() }
            }

            StyledButton(
                title: "Skip for now",
                style: MutedSecondaryButtonStyle(),
                isEnabled: !viewModel.isSaving && !isSubmittingSkip,
                isLoading: isSubmittingSkip
            ) {
                Task { await dismissPromptForNow() }
            }
        }
    }

    var combinedErrorMessage: String? {
        if let skipErrorMessage, !skipErrorMessage.isEmpty {
            return skipErrorMessage
        }
        return viewModel.errorMessage
    }

    func saveProfileChanges() async {
        skipErrorMessage = nil
        if viewModel.hasPendingChanges {
            let saved = await viewModel.save(currentUser: authViewModel.currentUser)
            guard saved else { return }
        }
        _ = await authViewModel.dismissProfileCompletionPrompt()
        dismiss()
    }

    func dismissPromptForNow() async {
        guard !isSubmittingSkip else { return }
        skipErrorMessage = nil
        isSubmittingSkip = true
        let dismissed = await authViewModel.dismissProfileCompletionPrompt()
        isSubmittingSkip = false
        if dismissed {
            dismiss()
        } else {
            skipErrorMessage = authViewModel.errorMessage ?? "Couldn't update this preference right now."
        }
    }

    func handleProfilePhotoSelection(_ newValue: PhotosPickerItem?) async {
        guard let newValue else { return }
        do {
            guard let data = try await newValue.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                viewModel.setPhotoSelectionError("Couldn't read that photo. Try another one.")
                return
            }
            let prepared = image.normalizedOrientation().resized(maxDimension: 1024)
            let trimmed = prepared.trimmedTransparentBorders() ?? prepared
            pendingCropImage = trimmed
            isShowingImageCropper = true
        } catch {
            viewModel.setPhotoSelectionError("Couldn't load that photo. Try another one.")
        }
    }
}

#Preview {
    NavigationStack {
        FinishProfileSetupView()
            .environmentObject(AuthViewModel())
    }
}
