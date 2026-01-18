import SwiftUI

struct MessagingPermissionsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = MessagingPermissionsViewModel()
    @State private var toastMessage: ToastMessage?

    var body: some View {
        List {
            Section {
                Text("Choose who can send you new message requests.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            Section {
                if authViewModel.currentUser == nil && viewModel.errorMessage == nil {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.loopedBackground)
                }

                ForEach(MessagePermission.allCases, id: \.self) { permission in
                    MessagingPermissionRow(
                        permission: permission,
                        isSelected: permission == viewModel.selectedPermission,
                        isUpdating: viewModel.updatingPermission == permission,
                        isDisabled: viewModel.isSaving || authViewModel.currentUser == nil
                    ) {
                        Task {
                            if let updatedUser = await viewModel.updatePermission(
                                permission,
                                currentUser: authViewModel.currentUser
                            ) {
                                authViewModel.currentUser = updatedUser
                                toastMessage = ToastMessage(text: "Messaging permissions updated.", kind: .success)
                            }
                        }
                    }
                }
            } footer: {
                Text("Existing conversations are unaffected.")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Messaging Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toast($toastMessage)
        .task {
            if authViewModel.currentUser == nil {
                await authViewModel.loadCurrentUser()
            }
            viewModel.load(from: authViewModel.currentUser)
        }
        .onChange(of: authViewModel.currentUser?.id) { _, _ in
            viewModel.load(from: authViewModel.currentUser)
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            guard let newValue else { return }
            toastMessage = ToastMessage(text: newValue, kind: .error)
        }
    }
}

private struct MessagingPermissionRow: View {
    let permission: MessagePermission
    let isSelected: Bool
    let isUpdating: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(permission.title)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(permission.subtitle)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                ZStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.loopedCustom(.semibold, size: 18))
                        .foregroundColor(isSelected ? .loopedSecondary : .loopedTextSecondary)
                        .opacity(isUpdating ? 0 : 1)

                    if isUpdating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .loopedSecondary))
                            .scaleEffect(0.7)
                    }
                }
                .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

#Preview {
    MessagingPermissionsView()
        .environmentObject(AuthViewModel())
}
