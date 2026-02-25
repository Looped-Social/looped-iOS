import Foundation
import UIKit

@MainActor
final class FinishProfileSetupViewModel: ObservableObject {
    @Published var bio: String = ""
    @Published var profilePhotoPreview: UIImage?
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?

    let bioCharacterLimit: Int

    private let userService: UserServiceProtocol
    private let mediaService: MediaServiceProtocol

    private var initialBio = ""
    private var profilePhotoPayload: ImageUploadPayload?
    private var hydratedUserId: Int?

    init(
        userService: UserServiceProtocol = UserService(),
        mediaService: MediaServiceProtocol = MediaService(),
        bioCharacterLimit: Int = 500
    ) {
        self.userService = userService
        self.mediaService = mediaService
        self.bioCharacterLimit = bioCharacterLimit
    }

    func hydrateIfNeeded(user: User?) {
        guard let user else { return }
        guard hydratedUserId != user.backendId else { return }
        hydratedUserId = user.backendId
        bio = user.bio ?? ""
        initialBio = normalized(bio)
        profilePhotoPreview = nil
        profilePhotoPayload = nil
        errorMessage = nil
        statusMessage = nil
    }

    var bioRemainingCharacters: Int {
        bioCharacterLimit - bio.count
    }

    var hasPendingChanges: Bool {
        normalized(bio) != initialBio
            || profilePhotoPayload != nil
    }

    var canSave: Bool {
        !isSaving && bio.count <= bioCharacterLimit && hasPendingChanges
    }

    func setSelectedPhotoImage(_ image: UIImage) {
        errorMessage = nil
        statusMessage = nil
        let prepared = image.normalizedOrientation().resized(maxDimension: 1024)
        guard let payload = makeUploadPayload(from: prepared) else {
            errorMessage = "Couldn't prepare that photo. Try another one."
            return
        }
        profilePhotoPreview = prepared
        profilePhotoPayload = payload
    }

    func clearSelectedPhoto() {
        profilePhotoPreview = nil
        profilePhotoPayload = nil
    }

    func setPhotoSelectionError(_ message: String) {
        errorMessage = message
    }

    func save(currentUser: User?) async -> Bool {
        guard let currentUser else {
            errorMessage = "We couldn't load your profile right now."
            return false
        }
        guard canSave else { return false }

        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            var uploadedProfileMediaAssetId: Int?
            if let profilePhotoPayload {
                let asset = try await mediaService.uploadImage(
                    data: profilePhotoPayload.data,
                    mimeType: profilePhotoPayload.mimeType,
                    width: profilePhotoPayload.width,
                    height: profilePhotoPayload.height,
                    actor: .user
                )
                uploadedProfileMediaAssetId = asset.id
            }

            let trimmedBio = normalized(bio)
            let didChangeProfileFields = trimmedBio != initialBio || uploadedProfileMediaAssetId != nil
            if didChangeProfileFields {
                _ = try await userService.updateProfile(
                    displayName: currentUser.displayName,
                    bio: trimmedBio.isEmpty ? nil : trimmedBio,
                    isAnonymous: currentUser.isAnonymous,
                    showFollowerCount: currentUser.showFollowerCount,
                    messagePermission: currentUser.messagePermission,
                    profileMediaAssetId: uploadedProfileMediaAssetId
                )
            }

            initialBio = trimmedBio
            profilePhotoPayload = nil
            statusMessage = "Saved."
            return true
        } catch {
            errorMessage = mapSaveError(error)
            return false
        }
    }
}

private extension FinishProfileSetupViewModel {
    func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func makeUploadPayload(from image: UIImage) -> ImageUploadPayload? {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        if imageHasAlpha(image), let pngData = image.pngData() {
            return ImageUploadPayload(data: pngData, mimeType: "image/png", width: width, height: height)
        }

        if let jpegData = image.jpegData(compressionQuality: 0.85) {
            return ImageUploadPayload(data: jpegData, mimeType: "image/jpeg", width: width, height: height)
        }

        return nil
    }

    func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }

    func mapSaveError(_ error: Error) -> String {
        if case let APIError.apiError(_, apiError, message) = error {
            switch apiError {
            case "invalid_profile_image":
                return "That image isn't supported. Try another photo."
            case "media_asset_not_found", "media_asset_forbidden":
                return "We couldn't use that photo. Please try again."
            default:
                if let message, !message.isEmpty {
                    return message
                }
                return apiError
            }
        }
        return error.localizedDescription
    }
}

private struct ImageUploadPayload {
    let data: Data
    let mimeType: String
    let width: Int
    let height: Int
}
