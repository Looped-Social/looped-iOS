import Foundation

final class MutedChatStore {
    static let shared = MutedChatStore()

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    private let userDefaults: UserDefaults

    private enum Keys {
        static let mutedConversationIds = "mutedConversationIds"
        static let mutedChannelIds = "mutedChannelIds"
    }

    func isConversationMuted(_ conversationId: Int) -> Bool {
        mutedConversationIds.contains(conversationId)
    }

    func setConversationMuted(_ muted: Bool, conversationId: Int) {
        var ids = mutedConversationIds
        if muted {
            ids.insert(conversationId)
        } else {
            ids.remove(conversationId)
        }
        userDefaults.set(Array(ids), forKey: Keys.mutedConversationIds)
    }

    func isChannelMuted(_ channelId: Int) -> Bool {
        mutedChannelIds.contains(channelId)
    }

    func setChannelMuted(_ muted: Bool, channelId: Int) {
        var ids = mutedChannelIds
        if muted {
            ids.insert(channelId)
        } else {
            ids.remove(channelId)
        }
        userDefaults.set(Array(ids), forKey: Keys.mutedChannelIds)
    }

    private var mutedConversationIds: Set<Int> {
        Set(userDefaults.array(forKey: Keys.mutedConversationIds) as? [Int] ?? [])
    }

    private var mutedChannelIds: Set<Int> {
        Set(userDefaults.array(forKey: Keys.mutedChannelIds) as? [Int] ?? [])
    }
}

