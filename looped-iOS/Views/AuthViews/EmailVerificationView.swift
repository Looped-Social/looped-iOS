import SwiftUI

struct EmailVerificationView: View {
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onContinue: () -> Void
    let onResend: () -> Void

    @State private var code = ""

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

                    VerificationCodeEntryView(code: $code)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.loopedMutedBackground)
                )
                .padding(.horizontal, 28)

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.loopedContrast)
                        .clipShape(Capsule())
                }
                .disabled(code.count < 6)
                .opacity(code.count < 6 ? 0.4 : 1)
                .padding(.horizontal, 32)

                Button(action: onResend) {
                    Text("Resend code")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedSecondary)
                }
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
    }
}

private extension EmailVerificationView {
    var header: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.loopedTextPrimary)
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }

            if totalSteps > 1 {
                VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
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
                        .fill(Color.white)
                        .frame(width: 28, height: 36)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
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
        currentStep: 3,
        totalSteps: 5,
        onBack: {},
        onContinue: {},
        onResend: {}
    )
}
