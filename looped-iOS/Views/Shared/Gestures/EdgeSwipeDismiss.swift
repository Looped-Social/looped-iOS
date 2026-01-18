import SwiftUI

private struct EdgeSwipeDismissModifier: ViewModifier {
    let edgeWidth: CGFloat
    let minimumTranslation: CGFloat
    let maximumVerticalTranslation: CGFloat
    let action: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    guard value.startLocation.x <= edgeWidth else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    guard abs(value.translation.height) <= maximumVerticalTranslation else { return }
                    guard value.translation.width >= minimumTranslation else { return }
                    action()
                }
        )
    }
}

extension View {
    func edgeSwipeToDismiss(
        edgeWidth: CGFloat = 24,
        minimumTranslation: CGFloat = 80,
        maximumVerticalTranslation: CGFloat = 60,
        action: @escaping () -> Void
    ) -> some View {
        modifier(
            EdgeSwipeDismissModifier(
                edgeWidth: edgeWidth,
                minimumTranslation: minimumTranslation,
                maximumVerticalTranslation: maximumVerticalTranslation,
                action: action
            )
        )
    }
}

