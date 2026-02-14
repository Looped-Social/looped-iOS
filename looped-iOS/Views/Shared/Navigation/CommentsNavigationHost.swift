import SwiftUI

struct CommentsNavigationHost: View {
    let post: Post
    let onDismiss: () -> Void

    @State private var path: [Route] = [.comments]

    enum Route: Hashable {
        case comments
        case hashtag(String)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Color.loopedBackground
                .ignoresSafeArea()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .comments:
                        CommentsView(
                            post: post,
                            presentationStyle: .navigation,
                            onOpenHashtag: { hashtag in
                                path.append(.hashtag(hashtag))
                            },
                            onDismiss: onDismiss
                        )
                    case .hashtag(let hashtag):
                        HashtagFeedView(hashtag: hashtag, presentationStyle: .navigation)
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
