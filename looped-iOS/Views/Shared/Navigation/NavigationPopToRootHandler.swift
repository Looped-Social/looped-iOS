import SwiftUI

struct NavigationPopToRootHandler: UIViewControllerRepresentable {
    @Binding var popToRootSignal: Int
    @Binding var lastProcessedSignal: Int
    @Binding var didPopOnLastSignal: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard context.coordinator.lastSignal != popToRootSignal else { return }
        guard let navigationController = uiViewController.navigationController else { return }
        context.coordinator.lastSignal = popToRootSignal

        DispatchQueue.main.async {
            let didPop = navigationController.viewControllers.count > 1
            didPopOnLastSignal = didPop
            lastProcessedSignal = popToRootSignal

            navigationController.popToRootViewController(animated: true)
        }
    }

    final class Coordinator {
        var lastSignal: Int = 0
    }
}
