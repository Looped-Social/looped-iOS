import SwiftUI
import PhotosUI
import UIKit

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var displayName: String = ""
    @State private var handle: String = ""
    @State private var bio: String = ""
    @State private var showFollowerCount: Bool = true
    @State private var initialDisplayName: String = ""
    @State private var initialHandle: String = ""
    @State private var initialBio: String = ""
    @State private var initialShowFollowerCount: Bool = true
    @State private var didCaptureInitialState = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var profileImageToUpload: UIImage?
    @State private var pendingCropImage: UIImage?
    @State private var isShowingImageCropper = false
    @State private var isShowingUnsavedChangesAlert = false
    @State private var isSaving = false
    @State private var toastMessage: ToastMessage?

    var body: some View {
        Group {
            if viewModel.user == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.loopedBackground.ignoresSafeArea())
            } else {
                VStack(spacing: 0) {
                    // Header
                    EditProfileHeader {
                        handleBackAction()
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
                                            ProfileAvatarView(
                                                imageURL: viewModel.user?.profileImageURL,
                                                size: 100,
                                                iconScale: 0.4
                                            )
                                        }

                                        // Edit icon overlay
                                        Circle()
                                            .fill(Color.loopedPrimary)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .font(.loopedCustom(size: 14))
                                                    .foregroundColor(.loopedWhite)
                                            )
                                    }
                                }
                                .onChange(of: selectedImage) { _, newValue in
                                    Task {
                                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data) {
                                            let prepared = uiImage
                                                .normalizedOrientation()
                                                .resized(maxDimension: 1024)
                                            let trimmed = prepared.trimmedTransparentBorders() ?? prepared
                                            pendingCropImage = trimmed
                                            isShowingImageCropper = true
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
                                        .background(Color.loopedWhite)
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
                                            .background(Color.loopedWhite)
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

                                // Handle (editable)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Handle")
                                        .font(.loopedSubBodyMedium)
                                        .foregroundColor(.loopedTextPrimary)

                                    HStack(spacing: 0) {
                                        Text("@")
                                            .font(.loopedBody)
                                            .foregroundColor(.loopedTextSecondary)
                                            .padding(.leading, 16)

                                        TextField("username", text: $handle)
                                            .font(.loopedBody)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 14)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()

                                        Spacer()
                                    }
                                    .background(Color.loopedWhite)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                    .cornerRadius(12)

                                    Text("Your unique identifier")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)
                                }

                                // Show Follower Count Toggle
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Show Follower Count")
                                            .font(.loopedBodyMedium)
                                            .foregroundColor(.loopedTextPrimary)

                                        Text("Display your follower count on your profile")
                                            .font(.loopedSmallText)
                                            .foregroundColor(.loopedTextSecondary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $showFollowerCount)
                                        .toggleStyle(SwitchToggleStyle(tint: Color.loopedPrimary))
                                }
                                .padding(.vertical, 12)

                                // Company & Job Title (navigate to settings)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Company")
                                        .font(.loopedSubBodyMedium)
                                        .foregroundColor(.loopedTextPrimary)

                                    NavigationLink(destination: SettingsView().environmentObject(AuthViewModel())) {
                                        HStack {
                                            Text(viewModel.user?.company ?? "")
                                                .font(.loopedBody)
                                                .foregroundColor(.loopedTextSecondary)

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.loopedCustom(size: 14))
                                                .foregroundColor(.loopedTextSecondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(Color.loopedTextSecondary.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                                        )
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Text("Go to Settings to verify a different company")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)
                                }
                            }
                            .padding(.horizontal, 20)

                            // Save Button
                            PrimaryButton(
                                title: "Save Changes",
                                isEnabled: !displayName.isEmpty && !handle.isEmpty && bio.count <= 150,
                                isLoading: isSaving
                            ) {
                                Task {
                                    _ = await saveProfile()
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
                .background(NavigationPopGestureDisabler(isEnabled: false))
                .onAppear {
                    guard !didCaptureInitialState else { return }

                    // Initialize with current user data (only once per presentation)
                    displayName = viewModel.user?.displayName ?? ""
                    handle = viewModel.user?.handle ?? ""
                    bio = viewModel.user?.bio ?? ""
                    showFollowerCount = viewModel.user?.showFollowerCount ?? true

                    initialDisplayName = normalized(displayName)
                    initialHandle = normalized(handle).lowercased()
                    initialBio = normalized(bio)
                    initialShowFollowerCount = showFollowerCount
                    didCaptureInitialState = true
                }
            }
        }
        .toast($toastMessage)
        .alert("Save changes?", isPresented: $isShowingUnsavedChangesAlert) {
            Button("Save") {
                Task {
                    _ = await saveProfile(dismissOnSuccess: true)
                }
            }
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes.")
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .sheet(isPresented: $isShowingImageCropper) {
            if let pendingCropImage {
                ProfileImageCropperView(
                    image: pendingCropImage,
                    onCancel: {
                        isShowingImageCropper = false
                        self.pendingCropImage = nil
                        selectedImage = nil
                    },
                    onConfirm: { cropped in
                        let prepared = cropped.normalizedOrientation().resized(maxDimension: 1024)
                        profileImageToUpload = prepared
                        profileImage = Image(uiImage: prepared)
                        isShowingImageCropper = false
                        self.pendingCropImage = nil
                    }
                )
            } else {
                EmptyView()
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        normalized(displayName) != initialDisplayName
            || normalized(handle).lowercased() != initialHandle
            || normalized(bio) != initialBio
            || showFollowerCount != initialShowFollowerCount
            || profileImageToUpload != nil
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleBackAction() {
        if isSaving {
            return
        }
        if hasUnsavedChanges {
            isShowingUnsavedChangesAlert = true
            return
        }
        dismiss()
    }

    private func saveProfile(dismissOnSuccess: Bool = false) async -> Bool {
        isSaving = true

        await viewModel.updateProfileWithPhoto(
            displayName: displayName.isEmpty ? nil : displayName,
            handle: handle.isEmpty ? nil : handle,
            bio: bio.isEmpty ? nil : bio,
            isAnonymous: viewModel.user?.isAnonymous ?? false,
            showFollowerCount: showFollowerCount,
            profileImage: profileImageToUpload
        )

        isSaving = false

        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                toastMessage = ToastMessage(text: errorMessage, kind: .error)
            }
            return false
        }

        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = ToastMessage(text: "Profile updated", kind: .success)
        }
        profileImageToUpload = nil

        initialDisplayName = normalized(displayName)
        initialHandle = normalized(handle).lowercased()
        initialBio = normalized(bio)
        initialShowFollowerCount = showFollowerCount

        if dismissOnSuccess {
            dismiss()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
        return true
    }
}

// MARK: - Edit Profile Header

struct EditProfileHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            LoopedBackButton(action: onBack)

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

private struct NavigationPopGestureDisabler: UIViewControllerRepresentable {
    let isEnabled: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let navigationController = uiViewController.navigationController else { return }
        if context.coordinator.originalValue == nil {
            context.coordinator.originalValue = navigationController.interactivePopGestureRecognizer?.isEnabled
        }
        navigationController.interactivePopGestureRecognizer?.isEnabled = isEnabled
    }

    func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        guard let navigationController = uiViewController.navigationController else { return }
        if let originalValue = coordinator.originalValue {
            navigationController.interactivePopGestureRecognizer?.isEnabled = originalValue
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var originalValue: Bool?
    }
}

private struct ProfileImageCropperView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var cropSide: CGFloat = 0
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Move and scale")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .padding(.top, 8)

                GeometryReader { geometry in
                    let side = min(geometry.size.width, geometry.size.height)
                    let baseScale = baseScale(for: side)
                    let maxOffset = maxOffsets(for: side, totalScale: baseScale * scale)

                    ZStack {
                        Color.loopedBackground

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: side, height: side)
                            .scaleEffect(scale)
                            .offset(clampedOffset(maxOffset: maxOffset))
                            .clipped()
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = clampOffset(
                                            CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            ),
                                            maxOffset: maxOffset
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = clampScale(lastScale * value)
                                        let updatedMaxOffset = maxOffsets(for: side, totalScale: baseScale * scale)
                                        offset = clampOffset(offset, maxOffset: updatedMaxOffset)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        let updatedMaxOffset = maxOffsets(for: side, totalScale: baseScale * scale)
                                        offset = clampOffset(offset, maxOffset: updatedMaxOffset)
                                        lastOffset = offset
                                    }
                            )

                        Circle()
                            .stroke(Color.loopedContrast.opacity(0.9), lineWidth: 2)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.loopedTextSecondary.opacity(0.15), radius: 10, x: 0, y: 6)
                    .onAppear {
                        cropSide = side
                        let initialMaxOffset = maxOffsets(for: side, totalScale: baseScale * scale)
                        offset = clampOffset(offset, maxOffset: initialMaxOffset)
                        lastOffset = offset
                    }
                    .onChange(of: geometry.size) { _, _ in
                        cropSide = side
                        let updatedMaxOffset = maxOffsets(for: side, totalScale: baseScale * scale)
                        offset = clampOffset(offset, maxOffset: updatedMaxOffset)
                        lastOffset = offset
                    }
                }
                .frame(height: 360)
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    HStack {
                        Text("Zoom")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                        Spacer()
                        Text("\(Int(scale * 100))%")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    Slider(value: $scale, in: 1...4, step: 0.01) {
                        Text("Zoom")
                    }
                    .labelsHidden()
                    .tint(.loopedPrimary)
                    .onChange(of: scale) { _, newValue in
                        scale = clampScale(newValue)
                        let base = baseScale(for: cropSide)
                        let updatedMaxOffset = maxOffsets(for: cropSide, totalScale: base * scale)
                        offset = clampOffset(offset, maxOffset: updatedMaxOffset)
                        lastOffset = offset
                        lastScale = scale
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.loopedSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard cropSide > 0, let cropped = cropImage(cropSide: cropSide) else {
                            onCancel()
                            return
                        }
                        onConfirm(cropped)
                    }
                    .foregroundColor(.loopedSecondary)
                }
            }
        }
    }
}

private extension ProfileImageCropperView {
    func clampScale(_ value: CGFloat) -> CGFloat {
        min(4, max(1, value))
    }

    func baseScale(for cropSide: CGFloat) -> CGFloat {
        guard cropSide > 0, image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(cropSide / image.size.width, cropSide / image.size.height)
    }

    func maxOffsets(for cropSide: CGFloat, totalScale: CGFloat) -> CGSize {
        guard cropSide > 0 else { return .zero }
        let displayedWidth = image.size.width * totalScale
        let displayedHeight = image.size.height * totalScale
        return CGSize(
            width: max(0, (displayedWidth - cropSide) / 2),
            height: max(0, (displayedHeight - cropSide) / 2)
        )
    }

    func clampOffset(_ value: CGSize, maxOffset: CGSize) -> CGSize {
        CGSize(
            width: min(maxOffset.width, max(-maxOffset.width, value.width)),
            height: min(maxOffset.height, max(-maxOffset.height, value.height))
        )
    }

    func clampedOffset(maxOffset: CGSize) -> CGSize {
        clampOffset(offset, maxOffset: maxOffset)
    }

    func cropImage(cropSide: CGFloat) -> UIImage? {
        let source = image.normalizedOrientation()
        guard let cgImage = source.cgImage, cropSide > 0 else { return nil }

        let base = baseScale(for: cropSide)
        let totalScale = base * scale
        guard totalScale > 0 else { return nil }

        let maxOffset = maxOffsets(for: cropSide, totalScale: totalScale)
        let clamped = clampOffset(offset, maxOffset: maxOffset)

        let displayedWidth = source.size.width * totalScale
        let displayedHeight = source.size.height * totalScale

        let originXInDisplayed = (displayedWidth - cropSide) / 2 - clamped.width
        let originYInDisplayed = (displayedHeight - cropSide) / 2 - clamped.height

        let cropXPoints = originXInDisplayed / totalScale
        let cropYPoints = originYInDisplayed / totalScale
        let cropSizePoints = cropSide / totalScale

        let pixelsPerPointX = CGFloat(cgImage.width) / source.size.width
        let pixelsPerPointY = CGFloat(cgImage.height) / source.size.height

        var cropRect = CGRect(
            x: cropXPoints * pixelsPerPointX,
            y: cropYPoints * pixelsPerPointY,
            width: cropSizePoints * pixelsPerPointX,
            height: cropSizePoints * pixelsPerPointY
        ).integral

        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        cropRect = cropRect.intersection(imageBounds)
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        return UIImage(cgImage: cropped, scale: source.scale, orientation: .up)
    }
}

#Preview {
    EditProfileView(viewModel: ProfileViewModel())
}
