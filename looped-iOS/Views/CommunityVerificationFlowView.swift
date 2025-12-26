import SwiftUI

struct CommunityVerificationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CommunityVerificationFlowViewModel
    let onComplete: () -> Void

    init(
        communityId: Int,
        communityName: String,
        onComplete: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: CommunityVerificationFlowViewModel(
                communityId: communityId,
                communityName: communityName
            )
        )
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let finishResponse = viewModel.finishResponse {
                        completionState(finishResponse)
                    } else if viewModel.selectedMethod == nil {
                        methodSelection
                    } else {
                        methodDetails
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.loopedTextPrimary)
                    .frame(width: 40, height: 40)
            }

            Text("Verify \(viewModel.communityName)")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var methodSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a verification method")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            ForEach(CommunityVerificationMethod.allCases, id: \.self) { method in
                Button(action: {
                    Task { await viewModel.selectMethod(method) }
                }) {
                    HStack {
                        Text(method.displayName)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)

                        Spacer()

                        if viewModel.selectedMethod == method {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.loopedPrimary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isLoading)
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .padding(.top, 12)
    }

    private var methodDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let method = viewModel.selectedMethod {
                Text("\(method.displayName) verification")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
            }

            if let instructions = viewModel.startResponse?.instructions, !instructions.isEmpty {
                Text(instructions)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            if let devCode = viewModel.startResponse?.devCode {
                Text("Dev code: \(devCode)")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            verificationInput

            HStack(spacing: 12) {
                Button(action: viewModel.resetSelection) {
                    Text("Change method")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedSecondary)
                }

                Spacer()

                Button(action: {
                    Task { await viewModel.submit() }
                }) {
                    Text("Submit")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.loopedPrimary)
                        .clipShape(Capsule())
                }
                .disabled(viewModel.isLoading)
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var verificationInput: some View {
        if viewModel.selectedMethod == .email {
            TextField("Verification code", text: $viewModel.code)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                .padding(12)
                .background(Color.loopedMutedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if viewModel.selectedMethod == .video {
            TextField("Media key", text: $viewModel.mediaKey)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                .padding(12)
                .background(Color.loopedMutedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if viewModel.selectedMethod == .thirdparty {
            TextField("Provider token", text: $viewModel.token)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                .padding(12)
                .background(Color.loopedMutedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func completionState(_ response: CommunityVerificationFinishResponse) -> some View {
        let title = response.verified ? "Verification submitted" : "Verification pending"
        let subtitle = response.verified ? "You can now post in this community." : "We will notify you when verification completes."

        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: response.verified ? "checkmark.seal.fill" : "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundColor(response.verified ? .loopedPrimary : .loopedSecondary)

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Text(subtitle)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)

            if let expiresAt = response.expiresAt {
                Text("Expires \(Self.expiryFormatter.string(from: expiresAt))")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            Button(action: {
                onComplete()
                dismiss()
            }) {
                Text("Done")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.loopedPrimary)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding(.top, 20)
    }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    CommunityVerificationFlowView(communityId: 1, communityName: "Finance") {}
}
