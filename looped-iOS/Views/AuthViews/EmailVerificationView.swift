import SwiftUI

struct EmailVerificationView: View {
    let communityId: Int?
    let communityName: String
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    let onComplete: () async -> Bool
    let showsHeader: Bool

    @StateObject private var viewModel: CommunityEmailVerificationViewModel
    @FocusState private var isVerificationCodeFieldFocused: Bool
    @State private var isCompletingAfterVerification = false

    init(
        communityId: Int?,
        communityName: String,
        currentStep: Int,
        totalSteps: Int,
        onBack: @escaping () -> Void,
        onSkip: (() -> Void)? = nil,
        onComplete: @escaping () async -> Bool,
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
            ZStack {
                Color.loopedBackground
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissCodeKeyboardIfNeeded()
                    }

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
                            inboxDeliveryHintCard
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedError)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 8)
                        }

                        if let statusMessage = displayStatusMessage {
                            Text(statusMessage)
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
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

                    if viewModel.stage == .enterEmail {
                        domainSupportHint
                            .padding(.horizontal, 32)
                            .padding(.top, 10)
                    }

                    if viewModel.stage == .enterCode {
                        Button(action: {
                            Task {
                                await viewModel.resendCode()
                                focusCodeFieldSoon()
                            }
                        }) {
                            Text("Resend email")
                                .font(canResendCode ? .loopedSubBodyBold : .loopedSubBodyRegular)
                                .foregroundColor(
                                    canResendCode ? .loopedSecondary : .loopedTextSecondary
                                )
                                .underline(canResendCode)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canResendCode)
                        .padding(.top, 12)

                        if let resendCooldownMessage {
                            Text(resendCooldownMessage)
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 28)
                                .padding(.top, 4)
                        }
                    }

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
                        Button(action: {
                            Task { await viewModel.loadDomains() }
                        }) {
                            Text("Retry loading domains")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedSecondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
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
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            await viewModel.loadDomains()
            if viewModel.stage == .enterCode {
                focusCodeFieldSoon()
            }
        }
        .onChange(of: viewModel.stage) { _, newStage in
            if newStage == .enterCode {
                focusCodeFieldSoon()
            } else {
                isVerificationCodeFieldFocused = false
            }
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
                            .disabled(isVerificationTransitionLocked)
                    }
                }
            }
        }
        .loopedDisableKeyboardDismissOnTap(when: viewModel.stage == .enterCode)
        .loadingOverlay(
            isPresented: isVerificationTransitionLocked,
            title: isCompletingAfterVerification ? "Code verified" : "Verifying code…",
            subtitle: isCompletingAfterVerification ? "Taking you to the next step…" : nil
        )
    }
}

private extension EmailVerificationView {
    var header: some View {
        ZStack {
            HStack {
                LoopedBackButton(action: onBack)
                    .disabled(isVerificationTransitionLocked)
                Spacer()

                if let onSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedSecondary)
                    }
                    .disabled(isVerificationTransitionLocked)
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
                    .frame(maxWidth: .infinity, alignment: .leading)

	                domainSelector
                        .layoutPriority(1)
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
	        }
	    }

    var domainSupportHint: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Don't see your domain?")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.center)

            Text(emailEndingSupportText)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            domainSupportActions
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    var domainSupportActions: some View {
        ViewThatFits {
            HStack(spacing: 4) {
                Link("Contact us", destination: supportContactURL)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedSecondary)
                    .underline()

                Text("or")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)

                Link("email us here", destination: supportEmailURL)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedSecondary)
                    .underline()
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .center, spacing: 4) {
                Link("Contact us", destination: supportContactURL)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedSecondary)
                    .underline()

                Link("Email us here", destination: supportEmailURL)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedSecondary)
                    .underline()
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    var emailEndingSupportText: String {
        let endings = viewModel.domains.map { "@\($0)" }
        guard let first = endings.first else {
            return "No worries. We can help add your domain."
        }
        if endings.count == 1 {
            return "If your email doesn't end in \"\(first)\", no worries. We can help add your domain."
        }
        return "If your email doesn't end in \"\(first)\" or one of our other options, no worries. We can help add your domain."
    }

    var supportContactURL: URL {
        URL(string: "https://mylooped.app/contact")!
    }

    var supportEmailURL: URL {
        URL(string: "mailto:support@mylooped.app")!
    }

    var domainSelector: some View {
        Group {
            if viewModel.domains.count > 1 {
                Picker(selection: $viewModel.selectedDomain) {
                    ForEach(viewModel.domains, id: \.self) { domain in
                        Text("@\(domain)")
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
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
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(0.9)
            .allowsTightening(true)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minWidth: 86, maxWidth: 150, alignment: .leading)
            .background(Color.loopedTextSecondary.opacity(0.12))
            .cornerRadius(8)
    }

    var codeEntryCard: some View {
        VerificationCodeEntryView(
            code: $viewModel.code,
            isFocused: $isVerificationCodeFieldFocused
        )
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
        if isVerificationTransitionLocked {
            return false
        }
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

    var resendCooldownMessage: String? {
        let remaining = viewModel.retryAfterSecondsRemaining
        if remaining > 0 {
            let unit = remaining == 1 ? "second" : "seconds"
            return "You can resend email in \(remaining) \(unit)."
        }
        return nil
    }

    var canResendCode: Bool {
        !isVerificationTransitionLocked
            && viewModel.retryAfterSecondsRemaining == 0
            && !viewModel.isSendingCode
    }

    var displayStatusMessage: String? {
        guard let raw = viewModel.statusMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if raw.hasPrefix("Try again in ") || raw.hasPrefix("Code sent") {
            return nil
        }
        return raw
    }

    func handlePrimaryAction() {
        switch viewModel.stage {
        case .enterEmail:
            Task {
                isCompletingAfterVerification = false
                let success = await viewModel.sendCode()
                if success {
                    focusCodeFieldSoon()
                }
            }
        case .enterCode:
            Task {
                let success = await viewModel.submitCode()
                if success {
                    isVerificationCodeFieldFocused = false
                    isCompletingAfterVerification = true
                    let advanced = await onComplete()
                    if !advanced {
                        isCompletingAfterVerification = false
                        focusCodeFieldSoon()
                    }
                } else {
                    focusCodeFieldSoon()
                }
            }
        }
    }

    var isVerificationTransitionLocked: Bool {
        viewModel.isVerifyingCode || isCompletingAfterVerification
    }

    func focusCodeFieldSoon() {
        guard viewModel.stage == .enterCode else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isVerificationCodeFieldFocused = true
        }
    }

    func dismissCodeKeyboardIfNeeded() {
        guard viewModel.stage == .enterCode else { return }
        isVerificationCodeFieldFocused = false
    }

    var inboxDeliveryHintCard: some View {
        VStack(spacing: 6) {
            Text("Check spam and junk folders")
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Verification emails are often filtered and may not appear in your inbox.")
                .font(.loopedSmallText)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.loopedSecondary.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.loopedSecondary.opacity(0.24), lineWidth: 1)
                )
        )
    }
}

	private struct VerificationCodeEntryView: View {
	    @Binding var code: String
        @FocusState.Binding var isFocused: Bool

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
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: code) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > digits {
                        code = String(filtered.prefix(digits))
                    } else if filtered != newValue {
                        code = filtered
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isFocused = false
                        }
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedBlack)
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
        .onDisappear {
            isFocused = false
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
        onComplete: { true }
    )
}
