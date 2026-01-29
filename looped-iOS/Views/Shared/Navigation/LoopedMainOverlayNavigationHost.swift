import SwiftUI

enum LoopedMainOverlayDestination: Hashable, Identifiable {
    case settings
    case editProfile

    var id: String {
        switch self {
        case .settings: return "settings"
        case .editProfile: return "editProfile"
        }
    }
}

private struct LoopedPresentMainOverlayEnvironmentKey: EnvironmentKey {
    static let defaultValue: (LoopedMainOverlayDestination?) -> Void = { _ in }
}

extension EnvironmentValues {
    var loopedPresentMainOverlay: (LoopedMainOverlayDestination?) -> Void {
        get { self[LoopedPresentMainOverlayEnvironmentKey.self] }
        set { self[LoopedPresentMainOverlayEnvironmentKey.self] = newValue }
    }
}

struct LoopedMainOverlayNavigationHost: View {
    let destination: LoopedMainOverlayDestination
    let onDismiss: () -> Void

    @State private var path: [LoopedMainOverlayDestination]

    init(destination: LoopedMainOverlayDestination, onDismiss: @escaping () -> Void) {
        self.destination = destination
        self.onDismiss = onDismiss
        _path = State(initialValue: [destination])
    }

    var body: some View {
        Group {
            if destination == .editProfile {
                navigationStack
            } else {
                navigationStack
                    .edgeSwipeToDismiss { onDismiss() }
            }
        }
        .onChange(of: path) { _, newValue in
            if newValue.isEmpty {
                onDismiss()
            }
        }
    }

    private var navigationStack: some View {
        NavigationStack(path: $path) {
            Color.loopedBackground
                .ignoresSafeArea()
                .navigationDestination(for: LoopedMainOverlayDestination.self) { route in
                    switch route {
                    case .settings:
                        SettingsView()
                    case .editProfile:
                        UserSettingsView()
                    }
                }
        }
    }
}
