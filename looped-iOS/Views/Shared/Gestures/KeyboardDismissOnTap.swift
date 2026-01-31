import SwiftUI
import UIKit

private struct LoopedKeyboardDismissOnTapModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.background(KeyboardDismissTapGestureInstaller(onTap: action))
    }
}

private struct KeyboardDismissTapGestureInstaller: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        uiView.onTap = onTap
    }

    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        var onTap: (() -> Void)?
        private weak var installedOn: UIView?

        private lazy var tapRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.numberOfTapsRequired = 1
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            return recognizer
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            installRecognizerIfNeeded()
        }

        deinit {
            installedOn?.removeGestureRecognizer(tapRecognizer)
        }

        private func installRecognizerIfNeeded() {
            guard installedOn !== superview else { return }
            installedOn?.removeGestureRecognizer(tapRecognizer)
            installedOn = superview
            installedOn?.addGestureRecognizer(tapRecognizer)
        }

        @objc private func handleTap() {
            onTap?()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let touchedView = touch.view else { return true }
            return !touchedView.isWithinTextInput
        }
    }
}

private extension UIView {
    var isWithinTextInput: Bool {
        if self is UITextField || self is UITextView { return true }

        var current = superview
        while let view = current {
            if view is UITextField || view is UITextView { return true }
            current = view.superview
        }
        return false
    }
}

extension View {
    func loopedDismissKeyboardOnTap(_ action: @escaping () -> Void) -> some View {
        modifier(LoopedKeyboardDismissOnTapModifier(action: action))
    }
}

