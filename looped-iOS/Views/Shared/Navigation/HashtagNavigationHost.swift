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
            .background(
                NavigationLink(
                    isActive: Binding(
                        get: { activeHashtag != nil },
                        set: { isActive in
                            if !isActive {
                                activeHashtag = nil
                            }
                        }
                    )
                ) {
                    hashtagDestination
                } label: {
                    EmptyView()
                }
                .hidden()
            )
    }

    @ViewBuilder
    private var hashtagDestination: some View {
        if let route = activeHashtag {
            HashtagFeedView(hashtag: route.hashtag)
        } else {
            EmptyView()
        }
    }
}

extension View {
    func loopedHashtagNavigationHost() -> some View {
        modifier(HashtagNavigationHostModifier())
    }
}
