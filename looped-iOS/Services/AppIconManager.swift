import UIKit

/// Manages app icon changes
class AppIconManager: ObservableObject {
    static let shared = AppIconManager()

    @Published private(set) var currentIcon: AppIcon

    private init() {
        // Determine current icon on init
        let iconName = UIApplication.shared.alternateIconName
        self.currentIcon = AppIcon.allCases.first(where: { $0.iconName == iconName }) ?? .default
    }

    /// Available app icons
    enum AppIcon: String, CaseIterable, Identifiable {
        case `default` = "Default"
        case alternate = "Alternate"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .default:
                return "Default"
            case .alternate:
                return "Alternate"
            }
        }

        var iconName: String? {
            switch self {
            case .default:
                return nil // nil means primary icon
            case .alternate:
                return "AppIconAlt" // Must match asset catalog name
            }
        }

        var previewImageName: String {
            switch self {
            case .default:
                return "AppIcon" // For preview purposes
            case .alternate:
                return "AppIconAlt"
            }
        }
    }

    /// Change the app icon
    func setIcon(_ icon: AppIcon, completion: ((Bool) -> Void)? = nil) {
        guard UIApplication.shared.supportsAlternateIcons else {
            completion?(false)
            return
        }

        guard icon != currentIcon else {
            completion?(true)
            return
        }

        UIApplication.shared.setAlternateIconName(icon.iconName) { [weak self] error in
            DispatchQueue.main.async {
                if error == nil {
                    self?.currentIcon = icon
                    completion?(true)
                } else {
                    print("Error changing app icon: \(error?.localizedDescription ?? "Unknown error")")
                    completion?(false)
                }
            }
        }
    }
}
