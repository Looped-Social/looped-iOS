import SwiftUI

struct EmailVerificationView: View {
    let communityId: Int?
    let communityName: String
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    let onComplete: () -> Void

    @StateObject private var viewModel: CommunityEmailVerificationViewModel

    init(
        communityId: Int?,
        communityName: String,
        currentStep: Int,
        totalSteps: Int,
        onBack: @escaping () -> Void,
        onSkip: (() -> Void)? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.communityId = communityId
        self.communityName = communityName
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onSkip = onSkip
        self.onComplete = onComplete
        _viewModel = StateObject(
            wrappedValue: CommunityEmailVerificationViewModel(
                communityId: communityId,
                communityName: communityName
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                Spacer()
                    .frame(height: geometry.size.height * 0.08)

                VStack(spacing: 18) {
                    Text("Verify Your Email")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)

                    if viewModel.stage == .enterEmail {
                        emailEntryCard
                    } else {
                        codeEntryCard
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    if let statusMessage = viewModel.statusMessage {
                        Text(statusMessage)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    if let debugMessage = viewModel.debugMessage {
                        Text(debugMessage)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.loopedMutedBackground)
                )
                .padding(.horizontal, 28)

                Spacer()

                Button(action: handlePrimaryAction) {
                    Text(primaryButtonTitle)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.loopedPrimary)
                        .clipShape(Capsule())
                }
                .disabled(!primaryActionEnabled)
                .opacity(primaryActionEnabled ? 1 : 0.4)
                .padding(.horizontal, 32)

                if viewModel.stage == .enterCode {
                    Button(action: { Task { await viewModel.resendCode() } }) {
                        Text("Resend code")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedSecondary)
                    }
                    .padding(.top, 14)

                    Button(action: viewModel.resetToEmailEntry) {
                        Text("Change email")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }
                    .padding(.top, 4)
                }

                if viewModel.isFetchingDomains || viewModel.isSendingCode || viewModel.isVerifyingCode {
                    ProgressView()
                        .padding(.top, 12)
                        .tint(.loopedPrimary)
                }

                Spacer()
                    .frame(height: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
        .task {
            await viewModel.loadDomains()
        }
    }
}

private extension EmailVerificationView {
    var header: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.loopedCustom(.semibold, size: 20))
                        .foregroundColor(.loopedTextPrimary)
                        .frame(width: 40, height: 40)
                }
                Spacer()

                if let onSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedSecondary)
                    }
                    .padding(.trailing, 4)
                }
            }

            VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
        }
    }

    var emailEntryCard: some View {
        VStack(spacing: 16) {
            Text("Use your \(communityName) email")
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            HStack(spacing: 10) {
                TextField("username", text: $viewModel.emailLocalPart)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .tint(.loopedPrimary)
                    .textInputAutocapitalization(.none)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)

                domainSelector
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.loopedWhite)
            .cornerRadius(10)

            if viewModel.domains.count > 1 {
                Text("Select a domain")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
    }

    var domainSelector: some View {
        Group {
            if viewModel.domains.count > 1 {
                Picker(selection: $viewModel.selectedDomain) {
                    ForEach(viewModel.domains, id: \.self) { domain in
                        Text("@\(domain)")
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .tag(domain)
                    }
                } label: {
                    domainLabel
                }
                .pickerStyle(.menu)
            } else {
                domainLabel
            }
        }
    }

    var domainLabel: some View {
        Text(viewModel.selectedDomain.isEmpty ? "@domain" : "@\(viewModel.selectedDomain)")
            .font(.loopedBody)
            .foregroundColor(.loopedTextSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.loopedTextSecondary.opacity(0.12))
            .cornerRadius(8)
    }

    var codeEntryCard: some View {
        VerificationCodeEntryView(code: $viewModel.code)
    }

    var primaryButtonTitle: String {
        switch viewModel.stage {
        case .enterEmail:
            return "Send code"
        case .enterCode:
            return "Verify"
        }
    }

    var primaryActionEnabled: Bool {
        switch viewModel.stage {
        case .enterEmail:
            return viewModel.canSendCode && !viewModel.isSendingCode
        case .enterCode:
            return viewModel.canSubmitCode && !viewModel.isVerifyingCode
        }
    }

    func handlePrimaryAction() {
        switch viewModel.stage {
        case .enterEmail:
            Task {
                _ = await viewModel.sendCode()
            }
        case .enterCode:
            Task {
                let success = await viewModel.submitCode()
                if success {
                    onComplete()
                }
            }
        }
    }
}

private struct VerificationCodeEntryView: View {
    @Binding var code: String
    @FocusState private var isFocused: Bool

    private let digits = 6

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                ForEach(0..<digits, id: \.self) { index in
                    let character = characterAt(index)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.loopedWhite)
                        .frame(width: 28, height: 36)
                        .shadow(color: Color.loopedBlack.opacity(0.1), radius: 2, x: 0, y: 1)
                        .overlay(
                            Text(character)
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                        )
                }
            }

            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .foregroundColor(.loopedTextPrimary)
                .tint(.loopedPrimary)
                .opacity(0.01)
                .onChange(of: code) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > digits {
                        code = String(filtered.prefix(digits))
                    } else if filtered != newValue {
                        code = filtered
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        }
    }

    private func characterAt(_ index: Int) -> String {
        guard index < code.count else { return "" }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }
}

#Preview {
    EmailVerificationView(
        communityId: 1,
        communityName: "Looped",
        currentStep: 3,
        totalSteps: 5,
        onBack: {},
        onComplete: {}
    )
}
