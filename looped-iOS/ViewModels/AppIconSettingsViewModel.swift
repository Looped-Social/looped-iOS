import Foundation

@MainActor
final class AppIconSettingsViewModel: ObservableObject {
    @Published private(set) var selectedIcon: AppIconOption = .default
    @Published private(set) var supportsAlternateIcons = false
    @Published private(set) var isUpdating = false
    @Published var errorMessage: String?

    private let appIconService: AppIconServiceProtocol
    private var hasLoaded = false

    init() {
        self.appIconService = AppIconService()
    }

    init(appIconService: AppIconServiceProtocol) {
        self.appIconService = appIconService
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        supportsAlternateIcons = appIconService.supportsAlternateIcons
        selectedIcon = appIconService.currentIconOption()
    }

    func selectIcon(_ option: AppIconOption) async {
        guard supportsAlternateIcons else { return }
        guard !isUpdating else { return }
        guard option != selectedIcon else { return }

        let previousIcon = selectedIcon
        selectedIcon = option
        isUpdating = true
        defer { isUpdating = false }

        do {
            try await appIconService.setAppIcon(option)
            errorMessage = nil
        } catch {
            selectedIcon = previousIcon
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
