import SwiftUI

private enum SettingsModalRoute: Hashable {
    case settings
}

struct SettingsModalHost: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [SettingsModalRoute] = [.settings]

    var body: some View {
        NavigationStack(path: $path) {
            Color.loopedBackground
                .ignoresSafeArea()
                .navigationDestination(for: SettingsModalRoute.self) { route in
                    switch route {
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .onChange(of: path) { _, newValue in
            if newValue.isEmpty {
                dismiss()
            }
        }
    }
}

