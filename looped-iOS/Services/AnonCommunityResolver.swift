import Foundation

struct AnonCommunityResolver {
    private static let lastPostedCommunityKey = "lastPostedCommunityId"
    private static let lastSelectedCommunityKey = "lastSelectedCommunityId"

    static func resolve(
        preferredCommunityId: Int?,
        verificationService: CommunityVerificationServiceProtocol
    ) async -> Int? {
        if let preferredCommunityId, preferredCommunityId > 0 {
            return preferredCommunityId
        }
        let lastPosted = UserDefaults.standard.integer(forKey: lastPostedCommunityKey)
        if lastPosted > 0 {
            return lastPosted
        }
        let lastSelected = UserDefaults.standard.integer(forKey: lastSelectedCommunityKey)
        if lastSelected > 0 {
            return lastSelected
        }
        if let verification = try? await verificationService.fetchCommunityVerifications()
            .first(where: { $0.isActive }) {
            return verification.communityId
        }
        return nil
    }

    static func cacheSelectedCommunityId(_ communityId: Int?) {
        guard let communityId, communityId > 0 else { return }
        UserDefaults.standard.set(communityId, forKey: lastSelectedCommunityKey)
    }
}
