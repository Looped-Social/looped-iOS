import SwiftUI

private struct PreferCommunityShortNamesKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var preferCommunityShortNames: Bool {
        get { self[PreferCommunityShortNamesKey.self] }
        set { self[PreferCommunityShortNamesKey.self] = newValue }
    }
}

