import SwiftUI

struct AnonymousRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AnonBackupViewModel()

    @State private var backupPassphrase = ""
    @State private var backupPassphraseConfirm = ""
    @State private var restoreBlobId = ""
    @State private var restorePassphrase = ""
    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 24) {
                    anonAccessSection
                    backupSection
                    restoreSection

                    if let success = viewModel.successMessage {
                        statusBanner(text: success, color: .green)
                    }

                    if let error = viewModel.errorMessage {
                        statusBanner(text: error, color: .red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await viewModel.loadState() }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
            }

            HStack(spacing: 2) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 24)

                Text("ooped")
                    .font(.loopedBody24)
                    .foregroundColor(.loopedContrast)
            }

            Spacer()

            Text("Anonymous Backup")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create a Recovery Code")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Text("Set a passphrase to encrypt your anonymous persona. We store only the encrypted backup on the server.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
            Text("Save your Recovery Code and passphrase. If you lose them, we can’t restore your anonymous account.")
                .font(.loopedSmallText)
                .foregroundColor(.red)

            if let state = viewModel.backupState {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recovery Code")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextSecondary)

                    HStack {
                        Text(state.blobId)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Spacer()

                        Button(action: {
                            UIPasteboard.general.string = state.blobId
                            showCopiedToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedToast = false
                            }
                        }) {
                            Text(showCopiedToast ? "Copied" : "Copy")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedPrimary)
                        }
                    }
                    .padding(12)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("Save your Recovery Code and passphrase. If you lose them, you’ll need to generate a new backup.")
                        .font(.loopedSmallText)
                        .foregroundColor(.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Passphrase")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextSecondary)

                SecureField("Enter a passphrase", text: $backupPassphrase)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Passphrase")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextSecondary)

                SecureField("Re-enter passphrase", text: $backupPassphraseConfirm)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            PrimaryButton(
                title: viewModel.backupState == nil ? "Create Backup" : "Regenerate Backup",
                isEnabled: backupReady
            ) {
                Task {
                    await viewModel.createBackup(passphrase: backupPassphrase)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.loopedMutedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var anonAccessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Anonymous Access")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Text("Your anonymous access expires per community. Refresh by re-enrolling when needed.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)

            if viewModel.anonMemberships.isEmpty {
                Text("No anonymous access yet.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.anonMemberships) { membership in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(membership.communityName)
                                    .font(.loopedBodyMedium)
                                    .foregroundColor(.loopedTextPrimary)

                                Text(expiryText(for: membership))
                                    .font(.loopedSubBodyRegular)
                                    .foregroundColor(membership.isExpired ? .red : .loopedTextSecondary)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.loopedMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func expiryText(for membership: AnonCommunityMembershipDisplay) -> String {
        let dateText = Self.expiryFormatter.string(from: membership.expiresAt)
        return membership.isExpired ? "Expired \(dateText)" : "Expires \(dateText)"
    }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Restore on Another Device")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Text("Enter your Recovery Code and passphrase to restore your anonymous persona.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Recovery Code")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextSecondary)

                TextField("Paste your recovery code", text: $restoreBlobId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Passphrase")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextSecondary)

                SecureField("Enter passphrase", text: $restorePassphrase)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            PrimaryButton(
                title: "Restore Backup",
                isEnabled: restoreReady
            ) {
                Task {
                    await viewModel.restoreBackup(blobId: restoreBlobId.trimmed, passphrase: restorePassphrase)
                }
            }
        }
        .padding(16)
        .background(Color.loopedMutedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusBanner(text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: color == .green ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(color)
            Text(text)
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var backupReady: Bool {
        !backupPassphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && backupPassphrase == backupPassphraseConfirm
            && !viewModel.isLoading
    }

    private var restoreReady: Bool {
        !restoreBlobId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !restorePassphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isLoading
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    AnonymousRecoveryView()
}
