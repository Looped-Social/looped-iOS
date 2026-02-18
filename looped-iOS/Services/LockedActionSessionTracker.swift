import Foundation

@MainActor
enum LockedActionSessionTracker {
    private static var shownKeys = Set<String>()

    static func shouldShowSheet(for reason: LockReason, communityId: Int?) -> Bool {
        let key = makeKey(for: reason, communityId: communityId)
        guard shownKeys.contains(key) == false else { return false }
        shownKeys.insert(key)
        return true
    }

    private static func makeKey(for reason: LockReason, communityId: Int?) -> String {
        let communityPart = String(communityId ?? -1)
        return "\(communityPart):\(reason.sessionPresentationTypeKey)"
    }
}
