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
    func setIcon(_ icon: AppIcon, completion: ((Bool, String?) -> Void)? = nil) {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ Device does not support alternate icons")
            completion?(false, "Device does not support alternate icons")
            return
        }

        guard icon != currentIcon else {
            print("ℹ️ Icon is already set to \(icon.displayName)")
            completion?(true, nil)
            return
        }

        print("🔄 Attempting to change icon to: \(icon.displayName) (iconName: \(icon.iconName ?? "nil"))")

        UIApplication.shared.setAlternateIconName(icon.iconName) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error changing app icon: \(error.localizedDescription)")
                    completion?(false, error.localizedDescription)
                } else {
                    print("✅ Successfully changed icon to \(icon.displayName)")
                    self?.currentIcon = icon
                    completion?(true, nil)
                }
            }
        }
    }
}
