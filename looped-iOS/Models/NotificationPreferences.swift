import Foundation

enum NotificationPreferenceChannel: String, CaseIterable {
    case inApp = "in_app"
    case push
    case email
}

enum NotificationPreferenceType: String, CaseIterable {
    case follow
    case like
    case comment
    case reply
    case mention
    case postFromFollowed = "post_from_followed"
    case repost
    case announcement
    case system
}

extension NotificationChannelsDTO {
    func channel(_ channel: NotificationPreferenceChannel) -> NotificationChannelDTO {
        switch channel {
        case .inApp:
            return inApp
        case .push:
            return push
        case .email:
            return email
        }
    }

    mutating func setChannel(_ channel: NotificationPreferenceChannel, to value: NotificationChannelDTO) {
        switch channel {
        case .inApp:
            inApp = value
        case .push:
            push = value
        case .email:
            email = value
        }
    }
}

extension NotificationChannelsUpdateDTO {
    mutating func setChannel(_ channel: NotificationPreferenceChannel, update: NotificationChannelUpdateDTO) {
        switch channel {
        case .inApp:
            inApp = update
        case .push:
            push = update
        case .email:
            email = update
        }
    }
}

extension NotificationTypePreferencesDTO {
    func value(for type: NotificationPreferenceType) -> Bool {
        switch type {
        case .follow:
            return follow
        case .like:
            return like
        case .comment:
            return comment
        case .reply:
            return reply
        case .mention:
            return mention
        case .postFromFollowed:
            return postFromFollowed
        case .repost:
            return repost
        case .announcement:
            return announcement
        case .system:
            return system
        }
    }

    mutating func set(_ value: Bool, for type: NotificationPreferenceType) {
        switch type {
        case .follow:
            follow = value
        case .like:
            like = value
        case .comment:
            comment = value
        case .reply:
            reply = value
        case .mention:
            mention = value
        case .postFromFollowed:
            postFromFollowed = value
        case .repost:
            repost = value
        case .announcement:
            announcement = value
        case .system:
            system = value
        }
    }
}

extension NotificationTypePreferencesUpdateDTO {
    mutating func set(_ value: Bool, for type: NotificationPreferenceType) {
        switch type {
        case .follow:
            follow = value
        case .like:
            like = value
        case .comment:
            comment = value
        case .reply:
            reply = value
        case .mention:
            mention = value
        case .postFromFollowed:
            postFromFollowed = value
        case .repost:
            repost = value
        case .announcement:
            announcement = value
        case .system:
            system = value
        }
    }
}
