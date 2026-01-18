import SwiftUI

struct MenuDestinationView: View {
    let destination: MenuDestination

    @ViewBuilder
    var body: some View {
        switch destination {
        case .posts:
            MyPostsView()
        case .replies:
            MyRepliesView()
        case .liked:
            LikedPostsView()
        case .saved:
            SavedPostsView()
        case .drafts:
            DraftsView()
        case .analytics:
            AnalyticsView()
        case .faq:
            FAQView()
        case .settings:
            SettingsView()
        }
    }
}
