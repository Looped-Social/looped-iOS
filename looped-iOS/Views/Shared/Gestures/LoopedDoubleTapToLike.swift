import SwiftUI

private struct LoopedDoubleTapToLikeModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded(action),
                including: .all
            )
    }
}

extension View {
    func loopedDoubleTapToLike(_ action: @escaping () -> Void) -> some View {
        modifier(LoopedDoubleTapToLikeModifier(action: action))
    }
}
