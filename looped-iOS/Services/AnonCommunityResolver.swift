import Foundation

struct AnonCommunityResolver {
    private static let lastPostedCommunityKey = "lastPostedCommunityId"
    private static let lastSelectedCommunityKey = "lastSelectedCommunityId"

    static func resolve(
        preferredCommunityId: Int?,
        preferredSpecializationId: Int?,
        verificationService: CommunityVerificationServiceProtocol,
        communityService: CommunityServiceProtocol = CommunityService()
    ) async -> Int? {
        let lastPosted = UserDefaults.standard.integer(forKey: lastPostedCommunityKey)
        let lastSelected = UserDefaults.standard.integer(forKey: lastSelectedCommunityKey)
        var candidates: [Int] = []
        if let preferredCommunityId, preferredCommunityId > 0 {
            candidates.append(preferredCommunityId)
        }
        if let preferredSpecializationId,
           preferredSpecializationId > 0,
           !candidates.contains(preferredSpecializationId) {
            candidates.append(preferredSpecializationId)
        }
        if lastPosted > 0, !candidates.contains(lastPosted) {
            candidates.append(lastPosted)
        }
        if lastSelected > 0, !candidates.contains(lastSelected) {
            candidates.append(lastSelected)
        }

        let verifications = (try? await verificationService.fetchCommunityVerifications()) ?? []
        let activeVerifications = verifications.filter { $0.isActive }
        let activeVerificationIds = Set(activeVerifications.map(\.communityId))

        func candidateIsEligible(_ communityId: Int) async -> Bool {
            guard let permissions = try? await communityService.fetchCommunityPermissions(communityId: communityId) else {
                return activeVerificationIds.contains(communityId)
            }
            if !permissions.requiresVerification {
                return true
            }
            return activeVerificationIds.contains(communityId)
        }

        for candidate in candidates {
            if await candidateIsEligible(candidate) {
                return candidate
            }
        }

        if let verified = activeVerifications.first?.communityId {
            return verified
        }

        // If the user isn't verified in any community, specializations can still be anon-eligible.
        // Try picking a joined/followed specialization so the profile toggle can enroll.
        if activeVerifications.isEmpty {
            if let joined = try? await communityService.fetchJoinedSpecializations(type: nil),
               let specialization = joined.first {
                return specialization.id
            }
            if let followed = try? await communityService.fetchFollowedCommunities(limit: 50, cursor: nil, order: .relevant),
               let specialization = followed.items.first(where: { $0.kind == .specialization }) {
                return specialization.id
            }
        }
        return nil
    }

    static func cacheSelectedCommunityId(_ communityId: Int?) {
        guard let communityId, communityId > 0 else { return }
        UserDefaults.standard.set(communityId, forKey: lastSelectedCommunityKey)
    }
}
