import SwiftUI

struct NavigationCanPopReader: UIViewControllerRepresentable {
    @Binding var canPop: Bool?

    static func resolveCanPop(from navigationController: UINavigationController?) -> Bool? {
        guard let navigationController else { return nil }
        return navigationController.viewControllers.count > 1
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let canPopNow = Self.resolveCanPop(from: uiViewController.navigationController) else {
                return
            }
            guard canPop != canPopNow else { return }
            canPop = canPopNow
        }
    }
}
