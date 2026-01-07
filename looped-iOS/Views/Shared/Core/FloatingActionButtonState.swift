import Foundation
import SwiftUI

final class FloatingActionButtonState: ObservableObject {
    @Published var isHidden = false
}

private struct FloatingActionButtonStateKey: EnvironmentKey {
    static let defaultValue = FloatingActionButtonState()
}

extension EnvironmentValues {
    var floatingActionButtonState: FloatingActionButtonState {
        get { self[FloatingActionButtonStateKey.self] }
        set { self[FloatingActionButtonStateKey.self] = newValue }
    }
}
