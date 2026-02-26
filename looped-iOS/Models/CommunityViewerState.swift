import Foundation

struct CommunityViewerState: Equatable {
    let verificationStatus: CommunityViewerVerificationStatusDTO?
    let verificationVerifiedAt: Date?
    let verificationExpiresAt: Date?
    let canPost: Bool?
    let cannotPostReason: CommunityViewerCannotPostReasonDTO?

    init(dto: CommunityViewerDTO) {
        verificationStatus = dto.verificationStatus
        verificationVerifiedAt = dto.verificationVerifiedAt
        verificationExpiresAt = dto.verificationExpiresAt
        canPost = dto.canPost
        cannotPostReason = dto.cannotPostReason
    }
}
