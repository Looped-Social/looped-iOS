import SwiftUI
import UIKit

private enum LoopedKeyboardDismissTapGate {
    private static var suppressionCount = 0

    static var isSuppressed: Bool {
        suppressionCount > 0
    }

    static func activateSuppression() {
        suppressionCount += 1
    }

    static func deactivateSuppression() {
        suppressionCount = max(0, suppressionCount - 1)
    }
}

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
        private weak var installedOn: UIWindow?

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

        deinit {
            installedOn?.removeGestureRecognizer(tapRecognizer)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installRecognizerIfNeeded()
        }

        private func installRecognizerIfNeeded() {
            guard installedOn !== window else { return }
            installedOn?.removeGestureRecognizer(tapRecognizer)
            installedOn = window
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
            if LoopedKeyboardDismissTapGate.isSuppressed {
                return false
            }
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
    func loopedDismissKeyboardOnTap() -> some View {
        modifier(
            LoopedKeyboardDismissOnTapModifier(action: {
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            })
        )
    }

    func loopedDismissKeyboardOnTap(_ action: @escaping () -> Void) -> some View {
        modifier(LoopedKeyboardDismissOnTapModifier(action: action))
    }

    func loopedDisableKeyboardDismissOnTap() -> some View {
        modifier(LoopedKeyboardDismissTapSuppressionModifier(isSuppressed: true))
    }
}

private struct LoopedKeyboardDismissTapSuppressionModifier: ViewModifier {
    let isSuppressed: Bool
    @State private var didActivate = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                synchronizeSuppressionState()
            }
            .onChange(of: isSuppressed) { _, _ in
                synchronizeSuppressionState()
            }
            .onDisappear {
                guard didActivate else { return }
                didActivate = false
                LoopedKeyboardDismissTapGate.deactivateSuppression()
            }
    }

    private func synchronizeSuppressionState() {
        if isSuppressed, !didActivate {
            didActivate = true
            LoopedKeyboardDismissTapGate.activateSuppression()
            return
        }
        if !isSuppressed, didActivate {
            didActivate = false
            LoopedKeyboardDismissTapGate.deactivateSuppression()
        }
    }
}

extension View {
    func loopedDisableKeyboardDismissOnTap(when isSuppressed: Bool) -> some View {
        modifier(LoopedKeyboardDismissTapSuppressionModifier(isSuppressed: isSuppressed))
    }
}
