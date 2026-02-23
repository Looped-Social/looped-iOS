import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct CommunityProfileViewModelTests {
    @Test
    func communityStateChanged_forSpecialization_refreshesJoinLimitEvenWhenDifferentCommunityChanges() async {
        let feedService = MockFeedService()
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()

        let initialLimit = makeJoinLimit(
            type: .major,
            canJoin: false,
            blockedReason: .verifySchool,
            requiredVerificationKind: .school,
            joinBlockedReason: .verificationRequired
        )
        let updatedLimit = makeJoinLimit(type: .major, canJoin: true)

        communityService.fetchSpecializationJoinLimitsHandler = { type in
            #expect(type == .major)
            return [updatedLimit]
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 300,
                name: "Computer Science",
                shortName: "CS",
                description: "",
                kind: .specialization,
                specializationType: .major,
                memberCount: 42,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: initialLimit
            ),
            feedService: feedService,
            communityService: communityService,
            verificationService: verificationService
        )

        NotificationCenter.default.post(
            name: .communityStateChanged,
            object: nil,
            userInfo: [LoopedNotificationUserInfoKey.communityId: 999]
        )
        await waitForNotificationTask()

        #expect(communityService.fetchSpecializationJoinLimitsCalls == [.major])
        #expect(communityService.fetchCommunityDetailsDTOCalls.isEmpty)
        #expect(viewModel.community.joinLimit == updatedLimit)
    }

    @Test
    func communityStateChanged_forMatchingCompany_refreshesDetailsAndVerification() async {
        let feedService = MockFeedService()
        let communityService = MockCommunityService()
        let verificationService = MockCommunityVerificationService()

        let refreshedDetails = CommunityDetailsDTO(
            id: 11,
            name: "UNC",
            shortName: "UNC",
            description: "Updated description",
            kind: "school",
            specializationType: nil,
            memberCount: 1234,
            bannerImageUrl: nil,
            profileImageUrl: nil,
            imageUrl: nil,
            icon: nil,
            isFollowing: true,
            isJoined: false,
            joinLimit: nil
        )

        communityService.fetchCommunityDetailsDTOHandler = { communityId, kind in
            #expect(communityId == 11)
            #expect(kind == .school)
            return refreshedDetails
        }

        verificationService.fetchCommunityVerificationsHandler = {
            [
                makeVerification(communityId: 11, kind: .school, status: .active)
            ]
        }

        let viewModel = CommunityProfileViewModel(
            community: CommunityProfileData(
                id: 11,
                name: "Old Name",
                shortName: nil,
                description: "",
                kind: .school,
                specializationType: .unknown,
                memberCount: 1,
                imageUrl: nil,
                isFollowing: false,
                isJoined: false,
                joinLimit: nil
            ),
            feedService: feedService,
            communityService: communityService,
            verificationService: verificationService
        )

        NotificationCenter.default.post(
            name: .communityStateChanged,
            object: nil,
            userInfo: [LoopedNotificationUserInfoKey.communityId: 11]
        )
        await waitForNotificationTask()

        #expect(communityService.fetchCommunityDetailsDTOCalls.count == 1)
        #expect(communityService.fetchCommunityDetailsDTOCalls.first?.communityId == 11)
        #expect(communityService.fetchCommunityDetailsDTOCalls.first?.kind == .school)
        #expect(verificationService.fetchCommunityVerificationsCallCount == 1)
        #expect(viewModel.community.name == "UNC")
        #expect(viewModel.verification?.communityId == 11)
        #expect(viewModel.verification?.status == .active)
    }
}

private func waitForNotificationTask() async {
    try? await Task.sleep(nanoseconds: 40_000_000)
}

private func makeJoinLimit(
    type: CommunitySpecializationType,
    canJoin: Bool,
    blockedReason: SpecializationJoinBlockedReason? = nil,
    requiredVerificationKind: SpecializationJoinRequiresVerificationKind? = nil,
    joinBlockedReason: SpecializationJoinBlockedReason? = nil
) -> SpecializationJoinLimit {
    let dto = SpecializationJoinLimitDTO(
        specializationType: type.rawValue,
        limit: 2,
        joinedCount: canJoin ? 1 : 2,
        remaining: canJoin ? 1 : 0,
        cooldownMonths: 6,
        cooldownActive: false,
        cooldownEndsAt: nil,
        cooldownDaysRemaining: nil,
        canJoin: canJoin,
        blockedReason: blockedReason?.rawValue,
        requiredVerificationKind: requiredVerificationKind?.rawValue,
        joinRequiresVerificationKind: requiredVerificationKind?.rawValue,
        joinBlockedReason: joinBlockedReason?.rawValue
    )
    return SpecializationJoinLimit(dto: dto)
}

private func makeVerification(
    communityId: Int,
    kind: CommunityKind,
    status: CommunityVerificationStatus
) -> CommunityVerification {
    CommunityVerification(
        communityId: communityId,
        communityName: "Community \(communityId)",
        communityKind: kind,
        method: .email,
        verified: status == .active || status == .expired,
        verifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
        expiresAt: nil,
        active: status == .active,
        status: status,
        rejectReason: nil,
        verifiedEmail: "user\(communityId)@example.com"
    )
}
