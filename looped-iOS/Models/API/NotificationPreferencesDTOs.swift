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
    var reply: Bool
    var mention: Bool
    var postFromFollowed: Bool
    var repost: Bool
    var announcement: Bool
    var system: Bool
    var dmMessage: Bool
    var channelMessage: Bool

    private enum CodingKeys: String, CodingKey {
        case follow
        case like
        case comment
        case reply
        case mention
        case postFromFollowed
        case repost
        case announcement
        case system
        case dmMessage
        case channelMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Default to enabled when fields are missing (backward-compatible with older servers).
        follow = try container.decodeIfPresent(Bool.self, forKey: .follow) ?? true
        like = try container.decodeIfPresent(Bool.self, forKey: .like) ?? true
        comment = try container.decodeIfPresent(Bool.self, forKey: .comment) ?? true
        reply = try container.decodeIfPresent(Bool.self, forKey: .reply) ?? true
        mention = try container.decodeIfPresent(Bool.self, forKey: .mention) ?? true
        postFromFollowed = try container.decodeIfPresent(Bool.self, forKey: .postFromFollowed) ?? true
        repost = try container.decodeIfPresent(Bool.self, forKey: .repost) ?? true
        announcement = try container.decodeIfPresent(Bool.self, forKey: .announcement) ?? true
        system = try container.decodeIfPresent(Bool.self, forKey: .system) ?? true
        dmMessage = try container.decodeIfPresent(Bool.self, forKey: .dmMessage) ?? true
        channelMessage = try container.decodeIfPresent(Bool.self, forKey: .channelMessage) ?? true
    }
}

struct NotificationPreferencesUpdateRequest: Codable {
    let channels: NotificationChannelsUpdateDTO
}

struct NotificationChannelsUpdateDTO: Codable {
    var inApp: NotificationChannelUpdateDTO? = nil
    var push: NotificationChannelUpdateDTO? = nil
    var email: NotificationChannelUpdateDTO? = nil

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
    var follow: Bool? = nil
    var like: Bool? = nil
    var comment: Bool? = nil
    var reply: Bool? = nil
    var mention: Bool? = nil
    var postFromFollowed: Bool? = nil
    var repost: Bool? = nil
    var announcement: Bool? = nil
    var system: Bool? = nil
    var dmMessage: Bool? = nil
    var channelMessage: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case follow
        case like
        case comment
        case reply
        case mention
        case postFromFollowed = "post_from_followed"
        case repost
        case announcement
        case system
        case dmMessage = "dm_message"
        case channelMessage = "channel_message"
    }
}
