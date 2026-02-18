import Foundation

extension NSNotification.Name {
    static let contentPreferencesChanged = NSNotification.Name("contentPreferencesChanged")
    static let communityStateChanged = NSNotification.Name("communityStateChanged")
    static let userBlockListChanged = NSNotification.Name("userBlockListChanged")
    static let notificationMarkedRead = NSNotification.Name("notificationMarkedRead")
    static let authGatingRequired = NSNotification.Name("authGatingRequired")
    static let profileRefreshRequested = NSNotification.Name("profileRefreshRequested")
}

enum LoopedNotificationUserInfoKey {
    static let communityId = "communityId"
    static let notificationId = "notificationId"
}
