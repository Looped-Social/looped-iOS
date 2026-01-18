import SwiftUI

struct CommentsNavigationHost: View {
    let post: Post
    let onDismiss: () -> Void

    @State private var path: [Route] = [.comments]

    enum Route: Hashable {
        case comments
    }

    var body: some View {
        NavigationStack(path: $path) {
            Color.loopedBackground
                .ignoresSafeArea()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .comments:
                        CommentsView(post: post, presentationStyle: .navigation, onDismiss: onDismiss)
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

