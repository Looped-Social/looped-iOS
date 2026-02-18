import SwiftUI

struct EmailVerificationView: View {
    let communityId: Int?
    let communityName: String
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    let onComplete: () -> Void
    let showsHeader: Bool

    @StateObject private var viewModel: CommunityEmailVerificationViewModel

    init(
        communityId: Int?,
        communityName: String,
        currentStep: Int,
        totalSteps: Int,
        onBack: @escaping () -> Void,
        onSkip: (() -> Void)? = nil,
        onComplete: @escaping () -> Void,
        showsHeader: Bool = true,
        ensureOnboardingVerificationStep: (() async -> Void)? = nil
    ) {
        self.communityId = communityId
        self.communityName = communityName
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onSkip = onSkip
        self.onComplete = onComplete
        self.showsHeader = showsHeader
        _viewModel = StateObject(
            wrappedValue: CommunityEmailVerificationViewModel(
                communityId: communityId,
                communityName: communityName,
                ensureOnboardingVerificationStep: ensureOnboardingVerificationStep
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if showsHeader {
                    header
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }

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

                if shouldShowRetryDomainsAction {
                    SecondaryButton(title: "Retry") {
                        Task { await viewModel.loadDomains() }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                }

                if viewModel.stage == .enterCode {
                    Button(action: { Task { await viewModel.resendCode() } }) {
                        Text(resendCodeTitle)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedSecondary)
                    }
                    .disabled(viewModel.retryAfterSecondsRemaining > 0 || viewModel.isSendingCode)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !showsHeader {
                ToolbarItem(placement: .principal) {
                    VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
                }

                if let onSkip {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip", action: onSkip)
                    }
                }
            }
        }
    }
}

private extension EmailVerificationView {
    var header: some View {
        ZStack {
            HStack {
                LoopedBackButton(action: onBack)
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

                Text("An email can only be actively verified by one account in this community at a time.")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

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
	            .background(
	                RoundedRectangle(cornerRadius: 10, style: .continuous)
	                    .fill(Color.loopedBackground)
	                    .overlay(
	                        RoundedRectangle(cornerRadius: 10, style: .continuous)
	                            .stroke(Color.loopedTextSecondary.opacity(0.18), lineWidth: 1)
	                    )
	            )

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

    var shouldShowRetryDomainsAction: Bool {
        viewModel.stage == .enterEmail
            && viewModel.domains.isEmpty
            && !viewModel.isFetchingDomains
            && viewModel.errorMessage != nil
    }

    var resendCodeTitle: String {
        if viewModel.retryAfterSecondsRemaining > 0 {
            return "Resend in \(viewModel.retryAfterSecondsRemaining)s"
        }
        return "Resend code"
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
	                        .fill(Color.loopedBackground)
	                        .frame(width: 28, height: 36)
	                        .overlay(
	                            RoundedRectangle(cornerRadius: 6, style: .continuous)
	                                .stroke(borderColor(for: index), lineWidth: 1)
	                        )
	                        .shadow(color: Color.loopedTextSecondary.opacity(0.12), radius: 1, x: 0, y: 1)
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

	    private func borderColor(for index: Int) -> Color {
	        guard isFocused else { return .loopedTextSecondary.opacity(0.18) }
	        let nextIndex = min(code.count, digits - 1)
	        return index == nextIndex ? .loopedPrimary : .loopedTextSecondary.opacity(0.18)
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
