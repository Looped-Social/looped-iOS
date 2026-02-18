import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct AppIconSettingsViewModelTests {

    @Test
    func loadIfNeeded_setsSupportAndCurrentSelection() async {
        let service = MockAppIconService()
        service.supportsAlternateIcons = true
        service.currentOption = .alternate

        let viewModel = AppIconSettingsViewModel(appIconService: service)
        await viewModel.loadIfNeeded()

        #expect(viewModel.supportsAlternateIcons == true)
        #expect(viewModel.selectedIcon == .alternate)
    }

    @Test
    func selectIcon_success_updatesSelection() async {
        let service = MockAppIconService()
        service.supportsAlternateIcons = true
        service.currentOption = .default

        let viewModel = AppIconSettingsViewModel(appIconService: service)
        await viewModel.loadIfNeeded()
        await viewModel.selectIcon(.alternate)

        #expect(viewModel.selectedIcon == .alternate)
        #expect(viewModel.errorMessage == nil)
        #expect(service.setCalls == [.alternate])
    }

    @Test
    func selectIcon_failure_rollsBackAndSetsError() async {
        let service = MockAppIconService()
        service.supportsAlternateIcons = true
        service.currentOption = .default
        service.setHandler = { _ in throw TestError(message: "switch failed") }

        let viewModel = AppIconSettingsViewModel(appIconService: service)
        await viewModel.loadIfNeeded()
        await viewModel.selectIcon(.alternate)

        #expect(viewModel.selectedIcon == .default)
        #expect(viewModel.errorMessage == "switch failed")
        #expect(service.setCalls == [.alternate])
    }

    @Test
    func selectIcon_whenUnsupported_doesNothing() async {
        let service = MockAppIconService()
        service.supportsAlternateIcons = false

        let viewModel = AppIconSettingsViewModel(appIconService: service)
        await viewModel.loadIfNeeded()
        await viewModel.selectIcon(.alternate)

        #expect(viewModel.selectedIcon == .default)
        #expect(service.setCalls.isEmpty)
    }
}

@MainActor
private final class MockAppIconService: AppIconServiceProtocol {
    var supportsAlternateIcons = false
    var currentOption: AppIconOption = .default
    var setCalls: [AppIconOption] = []
    var setHandler: ((AppIconOption) async throws -> Void)?

    func currentIconOption() -> AppIconOption {
        currentOption
    }

    func setAppIcon(_ option: AppIconOption) async throws {
        setCalls.append(option)
        if let setHandler {
            try await setHandler(option)
        }
        currentOption = option
    }
}
