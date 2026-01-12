import Foundation
import UIKit

@MainActor
final class PhotoIdVerificationViewModel: ObservableObject {
    @Published private(set) var isPreparing = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var isAlreadyVerifiedOrPending = false
    @Published var errorMessage: String?
    @Published var showErrorAlert = false

    private let service: PhotoIdVerificationServiceProtocol
    private var session: PhotoIdVerificationStartResponse?
    private var didPrepare = false

    init(service: PhotoIdVerificationServiceProtocol = PhotoIdVerificationService()) {
        self.service = service
    }

    var maxUploadBytes: Int? { session?.constraints.maxBytes }
    var allowedContentTypes: [String] { session?.constraints.allowedContentTypes ?? ["image/jpeg", "image/png"] }

    func prepareIfNeeded() async {
        guard !didPrepare else { return }
        didPrepare = true
        isPreparing = true
        defer { isPreparing = false }

        do {
            let status = try await service.status()
            switch status.status {
            case .approved, .pendingReview:
                isAlreadyVerifiedOrPending = true
                return
            case .none, .rejected, .unknown:
                break
            }
        } catch {
            // If status isn't available, still attempt start (e.g. some environments may not support status yet).
        }

        do {
            let start = try await service.start()
            if start.required.contains(where: { $0 != .selfie && $0 != .idFront && $0 != .idBack }) {
                throw APIError.apiError(code: 400, error: "unsupported_requirements", message: "This app version doesn't support the required documents.")
            }
            session = start
        } catch let apiError as APIError {
            switch apiError {
            case .apiError(_, let error, _):
                if error == "already_pending" || error == "already_verified" {
                    isAlreadyVerifiedOrPending = true
                    return
                }
            default:
                break
            }
            handleError(apiError)
        } catch {
            handleError(error)
        }
    }

    func submit(selfie: UIImage, idFront: UIImage, idBack: UIImage?) async -> Bool {
        guard let session else {
            handleError(APIError.apiError(code: 400, error: "missing_session", message: "Verification session not ready yet."))
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            guard let idBack else {
                throw APIError.apiError(code: 400, error: "id_back_required", message: "Please upload the back of your ID.")
            }

            let contentType = selectUploadContentType()
            let maxBytes = session.constraints.maxBytes

            let selfieData = try encode(image: selfie, contentType: contentType, maxBytes: maxBytes)
            let idFrontData = try encode(image: idFront, contentType: contentType, maxBytes: maxBytes)
            let idBackData = try encode(image: idBack, contentType: contentType, maxBytes: maxBytes)

            async let selfieKey = service.uploadDocument(
                uploadSessionId: session.uploadSessionId,
                kind: .selfie,
                data: selfieData,
                contentType: contentType
            )
            async let idFrontKey = service.uploadDocument(
                uploadSessionId: session.uploadSessionId,
                kind: .idFront,
                data: idFrontData,
                contentType: contentType
            )

            let idBackKey = try await service.uploadDocument(
                uploadSessionId: session.uploadSessionId,
                kind: .idBack,
                data: idBackData,
                contentType: contentType
            )

            let response = try await service.submit(
                uploadSessionId: session.uploadSessionId,
                selfieKey: try await selfieKey,
                idFrontKey: try await idFrontKey,
                idBackKey: idBackKey
            )

            guard response.status == "pending_review" else {
                throw APIError.apiError(
                    code: 400,
                    error: "verification_submit_failed",
                    message: "Upload finished but verification wasn’t submitted. Please try again."
                )
            }
            return true
        } catch {
            handleError(error)
            return false
        }
    }

    private func selectUploadContentType() -> String {
        if allowedContentTypes.contains("image/jpeg") { return "image/jpeg" }
        if allowedContentTypes.contains("image/png") { return "image/png" }
        return allowedContentTypes.first ?? "image/jpeg"
    }

    private func encode(image: UIImage, contentType: String, maxBytes: Int) throws -> Data {
        switch contentType {
        case "image/png":
            guard let data = image.pngData() else {
                throw APIError.apiError(code: 400, error: "encode_failed", message: "Failed to encode image.")
            }
            guard data.count <= maxBytes else {
                throw APIError.apiError(code: 400, error: "size_exceeds_limit", message: "Image exceeds upload limit.")
            }
            return data
        default:
            return try encodeJPEG(image: image, maxBytes: maxBytes)
        }
    }

    private func encodeJPEG(image: UIImage, maxBytes: Int) throws -> Data {
        let qualitySteps: [CGFloat] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4]
        for quality in qualitySteps {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
        }
        guard let last = image.jpegData(compressionQuality: 0.35) else {
            throw APIError.apiError(code: 400, error: "encode_failed", message: "Failed to encode image.")
        }
        guard last.count <= maxBytes else {
            throw APIError.apiError(code: 400, error: "size_exceeds_limit", message: "Image exceeds upload limit.")
        }
        return last
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showErrorAlert = true
    }
}
