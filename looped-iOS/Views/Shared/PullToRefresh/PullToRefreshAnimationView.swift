import SwiftUI

struct PullToRefreshAnimationView: View {
    let state: PullToRefreshState
    let options: PullToRefreshOptions
    
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: CGFloat = 0.3
    
    var body: some View {
        VStack {
            Group {
                switch state {
                case .idle:
                    // Hidden state
                    Color.loopedClear
                        .frame(height: 0)
                    
                case .pulling(let progress):
                    // Progressive animation during pull
                    logoView(progress: progress)
                        .scaleEffect(0.8 + (progress * 0.4))
                        .opacity(0.3 + (progress * 0.7))
                        .rotationEffect(.degrees(progress * 180))
                        .animation(.easeOut(duration: 0.1), value: progress)
                    
                case .refreshing:
                    // Continuous animation during refresh
                    logoView(progress: 1.0)
                        .scaleEffect(1.2)
                        .opacity(1.0)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
                        .onAppear {
                            rotationAngle = 360
                        }
                        .onDisappear {
                            rotationAngle = 0
                        }
                }
            }
        }
        .frame(height: getHeight())
    }
    
    private func logoView(progress: CGFloat) -> some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.loopedPrimary.opacity(progress * 0.6), Color.loopedPrimary.opacity(progress * 0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 60, height: 60)
                .scaleEffect(progress)
            
            // Inner glow ring
            Circle()
                .stroke(Color.loopedPrimary.opacity(progress * 0.3), lineWidth: 1)
                .frame(width: 45, height: 45)
                .scaleEffect(progress)
            
            // Logo
            Image("logo-animation")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .foregroundColor(.loopedPrimary)
        }
    }
    
    private func getHeight() -> CGFloat {
        switch state {
        case .idle:
            return 0
        case .pulling(let progress):
            return progress * options.threshold
        case .refreshing:
            return options.threshold
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        PullToRefreshAnimationView(
            state: .pulling(progress: 0.5),
            options: PullToRefreshOptions()
        )
        
        PullToRefreshAnimationView(
            state: .refreshing,
            options: PullToRefreshOptions()
        )
    }
    .padding()
    .background(Color.loopedBackground)
}