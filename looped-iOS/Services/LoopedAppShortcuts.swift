import Foundation

#if canImport(AppIntents)
import AppIntents

struct OpenMessagesAppIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Open Messages"
    static let description = IntentDescription("Open Looped directly to Messages.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let deepLinkURL = URL(string: "looped://messages")!
        try await requestToContinueInForeground {
            _ = DeepLinkRouter.shared.handleIncomingURL(deepLinkURL)
        }
        return .result()
    }
}

struct CreatePostAppIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Create Post"
    static let description = IntentDescription("Open Looped and start creating a new post.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let deepLinkURL = URL(string: "looped://create-post")!
        try await requestToContinueInForeground {
            _ = DeepLinkRouter.shared.handleIncomingURL(deepLinkURL)
        }
        return .result()
    }
}

struct LoopedAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreatePostAppIntent(),
            phrases: [
                "Create post in \(.applicationName)",
                "New post in \(.applicationName)",
                "Post in \(.applicationName)"
            ],
            shortTitle: "Create Post",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: OpenMessagesAppIntent(),
            phrases: [
                "Open messages in \(.applicationName)",
                "Show chats in \(.applicationName)",
                "Check messages in \(.applicationName)"
            ],
            shortTitle: "Messages",
            systemImageName: "message"
        )
    }
}
#endif
