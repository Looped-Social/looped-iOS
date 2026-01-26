import SwiftUI

struct LoopedInlineLoadingIndicator: View {
    var body: some View {
        LoopedPullToRefreshIndicator(
            fillProgress: 1,
            stretchProgress: 1,
            phase: .refreshing
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .accessibilityLabel("Loading")
    }
}

