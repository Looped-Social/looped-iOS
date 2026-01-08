import Foundation

enum PhotoIdDocumentKind: String, CaseIterable, Codable {
    case selfie = "selfie"
    case idFront = "id_front"
    case idBack = "id_back"

    var displayName: String {
        switch self {
        case .selfie: return "Selfie"
        case .idFront: return "ID Front"
        case .idBack: return "ID Back"
        }
    }
}

struct PhotoIdVerificationConstraints: Equatable {
    let allowedContentTypes: [String]
    let maxBytes: Int
}

struct PhotoIdVerificationStartResponse: Equatable {
    let status: String
    let method: String
    let uploadSessionId: String
    let required: [PhotoIdDocumentKind]
    let optional: [PhotoIdDocumentKind]
    let constraints: PhotoIdVerificationConstraints
}

struct PhotoIdVerificationPresignResponse: Equatable {
    let kind: PhotoIdDocumentKind
    let key: String
    let uploadUrl: URL
    let headers: [String: String]
}

struct PhotoIdVerificationSubmitResponse: Equatable {
    let verificationRequestId: Int
    let status: String
}

enum PhotoIdVerificationStatus: String, Equatable {
    case none
    case pendingReview = "pending_review"
    case approved
    case rejected
    case unknown

    init(rawValue: String) {
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

struct PhotoIdVerificationStatusResponse: Equatable {
    let method: String
    let status: PhotoIdVerificationStatus
}

