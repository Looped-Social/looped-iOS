import SwiftUI

struct HashtagRoute: Hashable, Identifiable {
    let hashtag: String

    var id: String { hashtag.lowercased() }
}

private struct LoopedOpenHashtagKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var loopedOpenHashtag: (String) -> Void {
        get { self[LoopedOpenHashtagKey.self] }
        set { self[LoopedOpenHashtagKey.self] = newValue }
    }
}

private struct HashtagNavigationHostModifier: ViewModifier {
    @State private var activeHashtag: HashtagRoute?

    func body(content: Content) -> some View {
        content
            .environment(\.loopedOpenHashtag) { rawHashtag in
                let trimmed = rawHashtag.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanHashtag = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
                guard !cleanHashtag.isEmpty else { return }
                activeHashtag = HashtagRoute(hashtag: cleanHashtag)
            }
            .navigationDestination(item: $activeHashtag) { route in
                HashtagFeedView(hashtag: route.hashtag)
            }
    }

}

extension View {
    func loopedHashtagNavigationHost() -> some View {
        modifier(HashtagNavigationHostModifier())
    }
}
