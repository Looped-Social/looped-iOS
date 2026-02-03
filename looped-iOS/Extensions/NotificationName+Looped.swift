import Foundation

extension NSNotification.Name {
    static let contentPreferencesChanged = NSNotification.Name("contentPreferencesChanged")
    static let communityStateChanged = NSNotification.Name("communityStateChanged")
}

enum LoopedNotificationUserInfoKey {
    static let communityId = "communityId"
}
