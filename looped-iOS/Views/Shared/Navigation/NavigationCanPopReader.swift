import SwiftUI

struct NavigationCanPopReader: UIViewControllerRepresentable {
    @Binding var canPop: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            let count = uiViewController.navigationController?.viewControllers.count ?? 0
            canPop = count > 1
        }
    }
}

