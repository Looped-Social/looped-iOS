import SwiftUI
import UIKit

extension View {
    @ViewBuilder
    func applyLockedActionSheetPageSizingIfAvailable() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}

struct SheetPresentationConfigurator: UIViewControllerRepresentable {
    let configure: (UISheetPresentationController) -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller(configure: configure)
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.configure = configure
        uiViewController.applyIfPossible()
    }

    final class Controller: UIViewController {
        var configure: (UISheetPresentationController) -> Void

        init(configure: @escaping (UISheetPresentationController) -> Void) {
            self.configure = configure
            super.init(nibName: nil, bundle: nil)
            view = UIView(frame: .zero)
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyIfPossible()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyIfPossible()
        }

        func applyIfPossible() {
            guard let sheet = nearestSheetController() else { return }
            configure(sheet)
        }

        private func nearestSheetController() -> UISheetPresentationController? {
            var node: UIViewController? = self
            while let current = node {
                if let sheet = current.presentationController as? UISheetPresentationController {
                    return sheet
                }
                node = current.parent
            }

            if let sheet = presentingViewController?.presentationController as? UISheetPresentationController {
                return sheet
            }
            return nil
        }
    }
}
