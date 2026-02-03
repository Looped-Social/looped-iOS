import SwiftUI

extension View {
    /// Ensures a minimum tappable area (Apple HIG recommends at least 44x44pt).
    /// Useful for icon-only buttons that are otherwise hard to hit.
    func loopedTapTarget(minSize: CGFloat = 44) -> some View {
        frame(minWidth: minSize, minHeight: minSize, alignment: .center)
            .contentShape(Rectangle())
    }
}

