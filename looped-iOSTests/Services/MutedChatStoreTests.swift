import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
struct MutedChatStoreTests {

    @Test
    func setConversationMuted_togglesState() {
        let store = MutedChatStore.shared
        let conversationId = 901
        defer { store.setConversationMuted(false, conversationId: conversationId) }

        store.setConversationMuted(true, conversationId: conversationId)
        #expect(store.isConversationMuted(conversationId))

        store.setConversationMuted(false, conversationId: conversationId)
        #expect(store.isConversationMuted(conversationId) == false)
    }

    @Test
    func setChannelMuted_togglesState() {
        let store = MutedChatStore.shared
        let channelId = 902
        defer { store.setChannelMuted(false, channelId: channelId) }

        store.setChannelMuted(true, channelId: channelId)
        #expect(store.isChannelMuted(channelId))

        store.setChannelMuted(false, channelId: channelId)
        #expect(store.isChannelMuted(channelId) == false)
    }
}
