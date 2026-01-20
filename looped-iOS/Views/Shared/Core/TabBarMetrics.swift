import SwiftUI

struct LoopedTabBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

private struct LoopedTabBarHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var loopedTabBarHeight: CGFloat {
        get { self[LoopedTabBarHeightEnvironmentKey.self] }
        set { self[LoopedTabBarHeightEnvironmentKey.self] = newValue }
    }
}

