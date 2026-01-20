import Foundation

actor CommunityPermissionsCache {
    static let shared = CommunityPermissionsCache()

    private var cachedByCommunityId: [Int: CommunityPermissions] = [:]
    private var inFlightByCommunityId: [Int: Task<CommunityPermissions?, Never>] = [:]

    func permissions(
        communityId: Int,
        communityService: CommunityServiceProtocol = CommunityService()
    ) async -> CommunityPermissions? {
        if let cached = cachedByCommunityId[communityId] {
            return cached
        }

        if let inFlight = inFlightByCommunityId[communityId] {
            return await inFlight.value
        }

        let task = Task<CommunityPermissions?, Never> {
            try? await communityService.fetchCommunityPermissions(communityId: communityId)
        }
        inFlightByCommunityId[communityId] = task
        let resolved = await task.value
        inFlightByCommunityId[communityId] = nil
        if let resolved {
            cachedByCommunityId[communityId] = resolved
        }
        return resolved
    }
}

