import Foundation
import UIKit

@MainActor
final class CommunityRequestFlowViewModel: ObservableObject {
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var submission: CommunityRequestSubmission?

    private let mediaService: MediaServiceProtocol
    private let requestService: CommunityRequestServiceProtocol

    init(
        mediaService: MediaServiceProtocol = MediaService(),
        requestService: CommunityRequestServiceProtocol = CommunityRequestService()
    ) {
        self.mediaService = mediaService
        self.requestService = requestService
    }

    func submit(
        name: String,
        about: String,
        kind: CommunityRequestKind?,
        imageData: Data?,
        contactEmail: String?,
        notifyWhenAvailable: Bool
    ) async -> Bool {
        guard !isSubmitting else { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAbout = about.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContactEmail = (contactEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContactEmail = trimmedContactEmail.isEmpty ? nil : trimmedContactEmail

        guard !trimmedName.isEmpty else {
            errorMessage = "Enter a community name."
            return false
        }

        guard !trimmedAbout.isEmpty else {
            errorMessage = "Add a short description."
            return false
        }

        guard let kind else {
            errorMessage = "Select a community type."
            return false
        }
        let resolvedKind = normalizedRequestKind(kind)
        guard resolvedKind != .unknown else {
            errorMessage = "Select a community type."
            return false
        }

        isSubmitting = true
        errorMessage = nil
        submission = nil
        defer { isSubmitting = false }

        var imageKey: String?
        if let imageData, !imageData.isEmpty {
            guard let payload = makeUploadPayload(from: imageData) else {
                errorMessage = "We couldn't read that image. Try another one."
                return false
            }
            do {
                let asset = try await mediaService.uploadImage(
                    data: payload.data,
                    mimeType: payload.mimeType,
                    width: payload.width,
                    height: payload.height
                )
                imageKey = asset.key
            } catch {
                errorMessage = mapError(error)
                return false
            }
        }

        do {
            let response = try await requestService.createCommunityRequest(
                kind: resolvedKind,
                name: trimmedName,
                about: trimmedAbout,
                imageKey: imageKey,
                contactEmail: normalizedContactEmail,
                notifyWhenAvailable: notifyWhenAvailable
            )
            submission = response
            return true
        } catch {
            errorMessage = mapError(error)
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func mapError(_ error: Error) -> String {
        if case let APIError.apiError(_, apiError, _) = error {
            switch apiError {
            case "invalid_kind":
                return "Pick Company or Field."
            case "name_required":
                return "Enter a community name."
            case "invalid_image":
                return "We couldn't use that image. Try a different file."
            case "image_not_owned":
                return "That image isn't linked to your account. Please upload again."
            case "community_exists":
                return "A community with this name already exists."
            case "request_already_pending":
                return "You already have a pending request for this community."
            case "invalid_contact_email":
                return "Enter a valid contact email."
            case "contact_email_required":
                return "Add a contact email so we can notify you."
            default:
                break
            }
        }
        return error.localizedDescription
    }

    private func makeUploadPayload(from data: Data) -> ImageUploadPayload? {
        guard let image = UIImage(data: data) else { return nil }
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        if imageHasAlpha(image), let pngData = image.pngData() {
            return ImageUploadPayload(data: pngData, mimeType: "image/png", width: width, height: height)
        }

        if let jpegData = image.jpegData(compressionQuality: 0.9) {
            return ImageUploadPayload(data: jpegData, mimeType: "image/jpeg", width: width, height: height)
        }

        return ImageUploadPayload(data: data, mimeType: "image/jpeg", width: width, height: height)
    }

    private func normalizedRequestKind(_ kind: CommunityRequestKind) -> CommunityRequestKind {
        switch kind {
        case .company, .field:
            return kind
        case .school:
            return .company
        case .major:
            return .field
        case .unknown:
            return .unknown
        }
    }

    private func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}

private struct ImageUploadPayload {
    let data: Data
    let mimeType: String
    let width: Int
    let height: Int
}
