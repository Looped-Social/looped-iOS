import UIKit
import AuthenticationServices

@MainActor
enum UIHelpers {
    static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let resolvedBase: UIViewController? = {
            if let base { return base }
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
        }()

        if let nav = resolvedBase as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = resolvedBase as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = resolvedBase?.presentedViewController {
            return topViewController(base: presented)
        }
        return resolvedBase
    }

    static func currentPresentationAnchor() -> ASPresentationAnchor? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
