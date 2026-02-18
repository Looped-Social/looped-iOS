import Foundation
import UIKit

enum AppIconOption: String, CaseIterable, Identifiable, Sendable {
    case `default` = "AppIcon"
    case alternate = "AppIconAlt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default:
            return "Classic"
        case .alternate:
            return "Reversed"
        }
    }

    var previewImageAssetName: String {
        switch self {
        case .default:
            return "AppIconPreviewDefault"
        case .alternate:
            return "AppIconPreviewAlt"
        }
    }

    var subtitle: String {
        switch self {
        case .default:
            return "Standard Looped icon"
        case .alternate:
            return "Alternate Looped icon"
        }
    }

    var iconNameForSystem: String? {
        switch self {
        case .default:
            return nil
        case .alternate:
            return rawValue
        }
    }

    init(systemIconName: String?) {
        guard let systemIconName,
              let option = AppIconOption(rawValue: systemIconName) else {
            self = .default
            return
        }
        self = option
    }
}

enum AppIconServiceError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Alternate app icons are not supported on this device."
        }
    }
}

@MainActor
protocol AppIconServiceProtocol {
    var supportsAlternateIcons: Bool { get }
    func currentIconOption() -> AppIconOption
    func setAppIcon(_ option: AppIconOption) async throws
}

@MainActor
final class AppIconService: AppIconServiceProtocol {
    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    func currentIconOption() -> AppIconOption {
        AppIconOption(systemIconName: UIApplication.shared.alternateIconName)
    }

    func setAppIcon(_ option: AppIconOption) async throws {
        guard supportsAlternateIcons else {
            throw AppIconServiceError.unsupported
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UIApplication.shared.setAlternateIconName(option.iconNameForSystem) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}
