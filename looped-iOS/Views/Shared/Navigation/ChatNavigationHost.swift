import SwiftUI

struct ChatNavigationHost: View {
    let conversation: Conversation?
    let channel: Channel?
    let conversationId: Int?
    let channelId: Int?
    let onDismiss: () -> Void

    @State private var path: [Route] = [.chat]

    enum Route: Hashable {
        case chat
    }

    init(
        conversation: Conversation?,
        channel: Channel?,
        conversationId: Int? = nil,
        channelId: Int? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.conversation = conversation
        self.channel = channel
        self.conversationId = conversationId
        self.channelId = channelId
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack(path: $path) {
            Color.loopedBackground
                .ignoresSafeArea()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .chat:
                        ChatView(
                            conversation: conversation,
                            channel: channel,
                            conversationId: conversationId,
                            channelId: channelId,
                            presentationStyle: .navigation,
                            onBackTapped: { path = [] }
                        )
                    }
                }
        }
        .onChange(of: path) { _, newValue in
            if newValue.isEmpty {
                onDismiss()
            }
        }
    }
}
