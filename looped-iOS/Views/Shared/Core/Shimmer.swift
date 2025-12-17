import SwiftUI

private struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = -0.8

    func body(content: Content) -> some View {
        guard isActive else { return AnyView(content) }

        let highlightOpacity: CGFloat = colorScheme == .dark ? 0.18 : 0.55
        let gradient = LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(highlightOpacity),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        return AnyView(
            content
                .overlay {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(gradient)
                            .rotationEffect(.degrees(18))
                            .offset(x: geometry.size.width * phase)
                    }
                    .allowsHitTesting(false)
                }
                .mask(content)
                .onAppear {
                    phase = -0.8
                    withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                        phase = 0.8
                    }
                }
        )
    }
}

extension View {
    func shimmering(_ isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

