import SwiftUI

struct LoopedLoadingOverlay: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        ZStack {
            Color.loopedBlack.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.loopedPrimary)
                    .scaleEffect(1.2)

                Text(title)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(Color.loopedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.loopedBlack.opacity(0.16), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 34)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isModal)
        }
    }
}

private struct LoadingOverlayPresenter: ViewModifier {
    let isPresented: Bool
    let title: String
    let subtitle: String?

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                LoopedLoadingOverlay(title: title, subtitle: subtitle)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

extension View {
    func loadingOverlay(isPresented: Bool, title: String, subtitle: String? = nil) -> some View {
        modifier(LoadingOverlayPresenter(isPresented: isPresented, title: title, subtitle: subtitle))
    }
}

