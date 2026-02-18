import SwiftUI

struct AppIconSettingsView: View {
    @ObservedObject var viewModel: AppIconSettingsViewModel

    var body: some View {
        List {
            Section {
                ForEach(AppIconOption.allCases) { option in
                    Button {
                        Task { await viewModel.selectIcon(option) }
                    } label: {
                        AppIconSelectionRow(
                            option: option,
                            isSelected: viewModel.selectedIcon == option
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isUpdating)
                }
            } header: {
                Text("Choose App Icon")
            } footer: {
                Text("The icon updates on your Home Screen right away.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .alert(
            "App Icon Update Failed",
            isPresented: errorPresentedBinding
        ) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unable to update app icon.")
        }
    }

    private var errorPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )
    }
}

private struct AppIconSelectionRow: View {
    let option: AppIconOption
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(option.previewImageAssetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? Color.loopedSecondary : Color.loopedTextSecondary.opacity(0.35),
                            lineWidth: isSelected ? 3 : 1
                        )
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
                Text(option.subtitle)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.loopedSymbol(.semibold, size: 20))
                    .foregroundColor(.loopedSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        AppIconSettingsView(viewModel: AppIconSettingsViewModel())
    }
}
