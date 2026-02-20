import WidgetKit
import SwiftUI

@main
struct LoopedWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickActionsWidget()
        InboxPulseWidget()
        ProfileStatsWidget()
        TrendingPostWidget()
        LockScreenCreateWidget()
        LockScreenSearchWidget()
        LockScreenChatWidget()
    }
}
