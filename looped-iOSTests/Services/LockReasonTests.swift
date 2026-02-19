import Testing
@testable import looped_iOS

@Suite
struct LockReasonTests {
    @Test
    func communityVerificationPrimaryButtonIncludesCommunityName() {
        let reason = LockReason.communityVerificationRequired(
            communityId: 42,
            communityName: "Acme",
            fieldName: nil,
            majorName: nil,
            joinCreditsRemaining: nil,
            alreadyVerifiedElsewhere: false,
            communityButtonShortName: nil
        )

        #expect(reason.primaryButtonTitle == "Verify Acme")
        #expect(reason.title(for: .like) == "Verify to Like")
        #expect(reason.body(for: .comment).contains("Acme"))
    }

    @Test
    func specializationJoinPrimaryButtonUsesSpecializationName() {
        let reason = LockReason.specializationJoinRequired(
            communityId: 7,
            communityName: "Machine Learning",
            fieldName: "Machine Learning",
            majorName: nil,
            joinCreditsRemaining: 2,
            alreadyVerifiedElsewhere: true
        )

        #expect(reason.primaryButtonTitle == "Join Machine Learning")
        #expect(reason.body(for: .like).contains("2 joins left"))
    }

    @Test
    func joinRequiresVerificationFirstUsesVerificationKindInPrimaryButton() {
        let reason = LockReason.joinRequiresVerificationFirst(
            communityId: 8,
            communityName: "Biology",
            fieldName: nil,
            majorName: "Biology",
            joinCreditsRemaining: 1,
            alreadyVerifiedElsewhere: false,
            requiredVerificationKind: .school,
            verifyTargetCommunityId: 33,
            verifyTargetCommunityName: "UNC Chapel Hill"
        )

        #expect(reason.primaryButtonTitle == "Verify UNC Chapel Hill")
        #expect(reason.body(for: .comment).contains("UNC Chapel Hill"))
    }
}
