import SwiftUI

enum ToastKind: Equatable {
    case info
    case loading
    case success
    case error

    var backgroundColor: Color {
        switch self {
        case .info:
            return .loopedSecondary
        case .loading:
            return .loopedSecondary
        case .success:
            return .loopedSuccess
        case .error:
            return .loopedError
        }
    }

    var foregroundColor: Color {
        .loopedWhite
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

    var body: some View {
        HStack(spacing: 10) {
            if message.kind == .loading {
                ProgressView()
                    .tint(message.kind.foregroundColor)
            }

            Text(message.text)
                .font(.loopedSubBodyRegular)
                .foregroundColor(message.kind.foregroundColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(message.kind.backgroundColor)
        .cornerRadius(14)
        .shadow(color: Color.loopedBlack.opacity(0.12), radius: 6, x: 0, y: 3)
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
                        LoopedToastView(message: presentedToast)
                            .padding(.horizontal, 20)
                            .padding(.bottom, bottomPadding(proxy: proxy))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .offset(y: isPresented ? 0 : 14)
                            .scaleEffect(isPresented ? 1 : 0.98)
                            .opacity(isPresented ? 1 : 0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isPresented)
                            .allowsHitTesting(false)
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
