import SwiftUI

struct NavigationCanPopReader: UIViewControllerRepresentable {
    @Binding var canPop: Bool?

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let navigationController = uiViewController.navigationController else {
                return
            }

            canPop = navigationController.viewControllers.count > 1
        }
    }
}
