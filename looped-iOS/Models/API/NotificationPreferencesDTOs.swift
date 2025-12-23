import Foundation

struct NotificationPreferencesResponseDTO: Codable {
    let notifications: NotificationPreferencesDTO
}

struct NotificationPreferencesDTO: Codable {
    var channels: NotificationChannelsDTO
}

struct NotificationChannelsDTO: Codable {
    var inApp: NotificationChannelDTO
    var push: NotificationChannelDTO
    var email: NotificationChannelDTO
}

struct NotificationChannelDTO: Codable {
    var enabled: Bool
    var types: NotificationTypePreferencesDTO
}

struct NotificationTypePreferencesDTO: Codable {
    var follow: Bool
    var like: Bool
    var comment: Bool
    var mention: Bool
    var postFromFollowed: Bool
    var announcement: Bool
    var system: Bool
}

struct NotificationPreferencesUpdateRequest: Codable {
    let channels: NotificationChannelsUpdateDTO
}

struct NotificationChannelsUpdateDTO: Codable {
    var inApp: NotificationChannelUpdateDTO?
    var push: NotificationChannelUpdateDTO?
    var email: NotificationChannelUpdateDTO?

    enum CodingKeys: String, CodingKey {
        case inApp = "in_app"
        case push
        case email
    }
}

struct NotificationChannelUpdateDTO: Codable {
    var enabled: Bool?
    var types: NotificationTypePreferencesUpdateDTO?
}

struct NotificationTypePreferencesUpdateDTO: Codable {
    var follow: Bool?
    var like: Bool?
    var comment: Bool?
    var mention: Bool?
    var postFromFollowed: Bool?
    var announcement: Bool?
    var system: Bool?

    enum CodingKeys: String, CodingKey {
        case follow
        case like
        case comment
        case mention
        case postFromFollowed = "post_from_followed"
        case announcement
        case system
    }
}
