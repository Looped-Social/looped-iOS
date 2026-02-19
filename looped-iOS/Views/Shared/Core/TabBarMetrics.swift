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

private struct LoopedTabBarVisibilityEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

private struct LoopedSetTabBarVisibilityEnvironmentKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    var loopedTabBarHeight: CGFloat {
        get { self[LoopedTabBarHeightEnvironmentKey.self] }
        set { self[LoopedTabBarHeightEnvironmentKey.self] = newValue }
    }

    var loopedIsTabBarVisible: Bool {
        get { self[LoopedTabBarVisibilityEnvironmentKey.self] }
        set { self[LoopedTabBarVisibilityEnvironmentKey.self] = newValue }
    }

    var loopedSetTabBarVisible: (Bool) -> Void {
        get { self[LoopedSetTabBarVisibilityEnvironmentKey.self] }
        set { self[LoopedSetTabBarVisibilityEnvironmentKey.self] = newValue }
    }
}
