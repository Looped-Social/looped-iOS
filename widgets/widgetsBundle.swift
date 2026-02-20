import WidgetKit
import SwiftUI

@main
struct LoopedWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickActionsWidget()
        ProfileStatsWidget()
        TrendingPostWidget()
        LockScreenCreateWidget()
        LockScreenSearchWidget()
    }
}
