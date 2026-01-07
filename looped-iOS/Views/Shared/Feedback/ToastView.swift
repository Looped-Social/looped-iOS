import SwiftUI

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

struct LoopedToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.loopedSubBodyRegular)
            .foregroundColor(.loopedBackground)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.loopedContrast)
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
                LoopedToastView(message: toast.text)
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
