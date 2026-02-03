import Foundation

extension NSNotification.Name {
    static let contentPreferencesChanged = NSNotification.Name("contentPreferencesChanged")
    static let communityStateChanged = NSNotification.Name("communityStateChanged")
    static let notificationMarkedRead = NSNotification.Name("notificationMarkedRead")
}

enum LoopedNotificationUserInfoKey {
    static let communityId = "communityId"
    static let notificationId = "notificationId"
}
