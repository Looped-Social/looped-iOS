import SwiftUI

struct MessagingPermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = MessagingPermissionsViewModel()
    @State private var toastMessage: ToastMessage?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    Text("Choose who can send you new message requests.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if authViewModel.currentUser == nil && viewModel.errorMessage == nil {
                        ProgressView()
                            .padding(.top, 8)
                    }

                    permissionCard

                    Text("Existing conversations are unaffected.")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
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

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.loopedCustom(.medium, size: 24))
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            Text("Messaging Permissions")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Image(systemName: "chevron.left")
                .font(.loopedCustom(.medium, size: 24))
                .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }

    private var permissionCard: some View {
        let permissions = MessagePermission.allCases
        let lastIndex = max(permissions.count - 1, 0)
        return VStack(spacing: 0) {
            ForEach(permissions.indices, id: \.self) { index in
                let permission = permissions[index]
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

                if index < lastIndex {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .background(Color.loopedTextSecondary.opacity(0.05))
        .cornerRadius(12)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

#Preview {
    MessagingPermissionsView()
        .environmentObject(AuthViewModel())
}
