import SwiftUI

struct LoopedPullToRefreshIndicator: View {
    enum Phase: Equatable {
        case pulling
        case refreshing
        case completing
    }

    /// 0...1 controls the left-to-right reveal.
    let fillProgress: CGFloat
    /// >= 0 controls how large the logo grows while pulling (can exceed 1).
    let stretchProgress: CGFloat
    let phase: Phase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotationDegrees: CGFloat = 0

    var body: some View {
        ZStack {
            Image("logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(placeholderColor)

            Image("logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.loopedPrimary)
                .mask(
                    GeometryReader { proxy in
                        Rectangle()
                            .frame(width: proxy.size.width * fillProgress, height: proxy.size.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                )
        }
        .frame(width: 44, height: 44)
        .scaleEffect(scale)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: fillProgress)
        .opacity(opacity)
        .animation(.easeOut(duration: 0.22), value: phase)
        .rotationEffect(.degrees(rotationDegrees))
        .onChange(of: phase) { _, newValue in
            switch newValue {
            case .pulling:
                rotationDegrees = 0
            case .refreshing:
                startSpinning()
            case .completing:
                if reduceMotion {
                    rotationDegrees = 0
                }
            }
        }
        .onAppear {
            if phase == .refreshing {
                startSpinning()
            }
        }
        .accessibilityHidden(true)
    }

    private var scale: CGFloat {
        switch phase {
        case .pulling:
            let normalized = max(0, stretchProgress)
            let capped = min(1.6, normalized)
            // 0 -> 0.85, 1.0 -> 1.22, 1.6 -> 1.35
            return 0.85 + 0.37 * min(1, capped) + 0.13 * max(0, capped - 1)
        case .refreshing:
            return 1.15
        case .completing:
            return 1.05
        }
    }

    private var opacity: CGFloat {
        switch phase {
        case .pulling:
            return max(0.001, min(1, fillProgress))
        case .refreshing:
            return 1
        case .completing:
            return 0
        }
    }

    private var placeholderColor: Color {
        Color(.sRGB, red: 175.0 / 255.0, green: 162.0 / 255.0, blue: 162.0 / 255.0, opacity: 1)
    }

    private func startSpinning() {
        guard !reduceMotion else {
            rotationDegrees = 0
            return
        }
        rotationDegrees = 0
        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
            rotationDegrees = 360
        }
    }
}

#Preview {
    VStack(spacing: 22) {
        LoopedPullToRefreshIndicator(fillProgress: 0.3, stretchProgress: 0.4, phase: .pulling)
        LoopedPullToRefreshIndicator(fillProgress: 1.0, stretchProgress: 1.0, phase: .pulling)
        LoopedPullToRefreshIndicator(fillProgress: 1.0, stretchProgress: 1.6, phase: .pulling)
        LoopedPullToRefreshIndicator(fillProgress: 1.0, stretchProgress: 1.0, phase: .refreshing)
    }
    .padding(40)
    .background(Color.loopedBackground)
}
