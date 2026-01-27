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
    let nonce: String?
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

enum PhotoIdVerificationStatus: String, Equatable, Codable {
    case none
    case pendingReview = "pending_review"
    case approved
    case rejected
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = PhotoIdVerificationStatus(rawValue: value) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct PhotoIdVerificationStatusResponse: Equatable {
    let method: String
    let status: PhotoIdVerificationStatus
}
