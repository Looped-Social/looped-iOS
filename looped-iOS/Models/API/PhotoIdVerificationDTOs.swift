import Foundation

struct PhotoIdVerificationStartResponseDTO: Decodable {
    let status: String
    let method: String
    let uploadSessionId: String
    let nonce: String?
    let required: [String]
    let optional: [String]
    let constraints: PhotoIdVerificationConstraintsDTO
}

struct PhotoIdVerificationConstraintsDTO: Decodable {
    let allowedContentTypes: [String]
    let maxBytes: Int
}

struct PhotoIdVerificationPresignRequestDTO: Encodable {
    let uploadSessionId: String
    let kind: String
    let contentType: String
    let sizeBytes: Int
}

struct PhotoIdVerificationPresignResponseDTO: Decodable {
    let kind: String
    let key: String
    let uploadUrl: String
    let headers: [String: String]
}

struct PhotoIdVerificationSubmitRequestDTO: Encodable {
    let uploadSessionId: String
    let documents: PhotoIdVerificationDocumentsDTO
}

struct PhotoIdVerificationDocumentsDTO: Encodable {
    let selfieKey: String
    let idFrontKey: String
    let idBackKey: String?
}

struct PhotoIdVerificationSubmitResponseDTO: Decodable {
    let verificationRequestId: Int
    let status: String
}

struct PhotoIdVerificationStatusResponseDTO: Decodable {
    let method: String
    let status: String
}
