import SwiftUI

enum ToastKind: Equatable {
    case info
    case success
    case error

    var backgroundColor: Color {
        switch self {
        case .info:
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
        Text(message.text)
            .font(.loopedSubBodyRegular)
            .foregroundColor(message.kind.foregroundColor)
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
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if let toast {
                LoopedToastView(message: toast)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: toast) { _, newValue in
            dismissTask?.cancel()
            guard newValue != nil else { return }
            let delay = UInt64(duration * 1_000_000_000)
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: delay)
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        toast = nil
                    }
                }
            }
        }
    }
}

extension View {
    func toast(_ toast: Binding<ToastMessage?>, duration: TimeInterval = 2) -> some View {
        modifier(ToastPresenter(toast: toast, duration: duration))
    }
}
