import SwiftUI

enum ToastKind: Equatable {
    case info
    case pending
    case warning
    case loading
    case success
    case error

    var title: String {
        switch self {
        case .info:
            return "Info"
        case .pending:
            return "Pending"
        case .warning:
            return "Warning"
        case .loading:
            return "Loading"
        case .success:
            return "Success"
        case .error:
            return "Error"
        }
    }

    var accentColor: Color {
        switch self {
        case .info, .pending, .loading:
            return .loopedSecondary
        case .warning:
            return .loopedWarning
        case .success:
            return .loopedSuccess
        case .error:
            return .loopedError
        }
    }

    var symbolName: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .pending:
            return "clock.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .loading:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var assetIconName: String? {
        switch self {
        case .success:
            return "success-toast"
        case .warning:
            return "warning-toast"
        case .error:
            return "error-toast"
        case .info, .pending, .loading:
            return nil
        }
    }

    var showsCloseButton: Bool {
        self != .loading
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let kind: ToastKind

    init(text: String, kind: ToastKind = .info) {
        self.text = text
        self.kind = kind
    }
}

struct LoopedToastView: View {
    let message: ToastMessage
    let onDismiss: () -> Void

    private let cornerRadius: CGFloat = 18
    private let iconSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if message.kind == .loading {
                    ProgressView()
                        .tint(message.kind.accentColor)
                        .scaleEffect(1.15)
                } else if let assetIconName = message.kind.assetIconName {
                    Image(assetIconName)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(message.kind.accentColor)
                } else {
                    Image(systemName: message.kind.symbolName)
                        .font(.loopedSymbol(.semibold, size: 26))
                        .foregroundStyle(message.kind.accentColor)
                }
            }
            .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.kind.title)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextStrong)
                    .lineLimit(1)

                Text(message.text)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if message.kind.showsCloseButton {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.loopedSymbol(.semibold, size: 12))
                        .foregroundColor(.loopedTextSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.loopedMutedBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.loopedContrast.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: Color.loopedBlack.opacity(0.16), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.kind.title): \(message.text)")
        .onTapGesture {
            guard message.kind != .loading else { return }
            onDismiss()
        }
    }
}

struct ToastPresenter: ViewModifier {
    @Binding var toast: ToastMessage?
    let duration: TimeInterval
    @State private var presentedToast: ToastMessage?
    @State private var isPresented = false
    @State private var dismissTask: Task<Void, Never>?
    @Environment(\.loopedTabBarHeight) private var tabBarHeight

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    if let presentedToast {
                        LoopedToastView(
                            message: presentedToast,
                            onDismiss: { toast = nil }
                        )
                            .frame(maxWidth: 560)
                            .padding(.horizontal, 16)
                            .padding(.bottom, bottomPadding(proxy: proxy))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .offset(y: isPresented ? 0 : 14)
                            .scaleEffect(isPresented ? 1 : 0.98)
                            .opacity(isPresented ? 1 : 0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isPresented)
                    }
                }
            }
            .onChange(of: toast) { _, newValue in
                dismissTask?.cancel()
                guard let newValue else {
                    withAnimation(.easeIn(duration: 0.2)) {
                        isPresented = false
                    }
                    dismissTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        presentedToast = nil
                    }
                    return
                }

                let toastId = newValue.id
                presentedToast = newValue
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    isPresented = true
                }

                if newValue.kind == .loading {
                    return
                }

                let delay = UInt64(duration * 1_000_000_000)
                dismissTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: delay)
                    guard presentedToast?.id == toastId else { return }
                    withAnimation(.easeIn(duration: 0.2)) {
                        isPresented = false
                    }
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard presentedToast?.id == toastId else { return }
                    toast = nil
                    presentedToast = nil
                }
            }
    }

    private func bottomPadding(proxy: GeometryProxy) -> CGFloat {
        // Keep toasts above the custom tab bar (which is inserted via `safeAreaInset`)
        // while still respecting the device's home indicator safe area.
        proxy.safeAreaInsets.bottom + tabBarHeight + 16
    }
}

extension View {
    func toast(_ toast: Binding<ToastMessage?>, duration: TimeInterval = 2) -> some View {
        modifier(ToastPresenter(toast: toast, duration: duration))
    }
}

private struct LoopedPresentToastEnvironmentKey: EnvironmentKey {
    static let defaultValue: (ToastMessage?) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Allows child views to present a global toast without threading bindings everywhere.
    var loopedPresentToast: (ToastMessage?) -> Void {
        get { self[LoopedPresentToastEnvironmentKey.self] }
        set { self[LoopedPresentToastEnvironmentKey.self] = newValue }
    }
}

#Preview("Toasts") {
    ZStack {
        Color.loopedBackground.ignoresSafeArea()

        VStack(spacing: 12) {
            LoopedToastView(message: ToastMessage(text: "Opera Passage station reserved successfully.", kind: .success)) {}
            LoopedToastView(message: ToastMessage(text: "Your reservation at this hotel is valid only if you book a room here.", kind: .warning)) {}
            LoopedToastView(message: ToastMessage(text: "Please select another charger.", kind: .error)) {}
            LoopedToastView(message: ToastMessage(text: "Syncing…", kind: .loading)) {}
        }
        .padding()
    }
}
