import SwiftUI
import UIKit

struct LoopedScrollSafeTapCaptureView: UIViewRepresentable {
    let allowableMovement: CGFloat
    let onTap: () -> Void

    init(allowableMovement: CGFloat = 6, onTap: @escaping () -> Void) {
        self.allowableMovement = allowableMovement
        self.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = true
        view.isAccessibilityElement = false

        let tap = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.minimumPressDuration = 0
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.allowableMovement = allowableMovement
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        context.coordinator.tapRecognizer = tap
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.tapRecognizer?.allowableMovement = allowableMovement
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: () -> Void
        weak var tapRecognizer: UILongPressGestureRecognizer?

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            if shouldSuppressTap(for: recognizer.view) { return }
            onTap()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !shouldSuppressTap(for: gestureRecognizer.view)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        private func shouldSuppressTap(for view: UIView?) -> Bool {
            guard let scrollView = view?.enclosingScrollView else { return false }
            return scrollView.isDragging || scrollView.isDecelerating
        }
    }
}

extension View {
    func loopedScrollSafeTap(allowableMovement: CGFloat = 6, _ action: @escaping () -> Void) -> some View {
        overlay(LoopedScrollSafeTapCaptureView(allowableMovement: allowableMovement, onTap: action))
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var current: UIView? = self
        while let view = current {
            if let scrollView = view as? UIScrollView { return scrollView }
            current = view.superview
        }
        return nil
    }
}
