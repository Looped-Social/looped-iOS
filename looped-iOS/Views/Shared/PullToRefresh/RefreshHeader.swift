import SwiftUI

struct RefreshHeader: View {
    let refreshProgress: CGFloat // 0.0 to 1.0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack {
            ZStack {
                // Logo image
                Image("logo-animation")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(rotationAngle))
                    .scaleEffect(0.8 + (refreshProgress * 0.4)) // Scale from 0.8 to 1.2
                    .opacity(0.3 + (refreshProgress * 0.7)) // Fade in as pulled
                
                // Optional: Add a subtle glow effect
                Circle()
                    .stroke(Color.loopedPrimary.opacity(refreshProgress * 0.3), lineWidth: 2)
                    .frame(width: 50, height: 50)
                    .scaleEffect(refreshProgress)
            }
        }
        .frame(height: 60)
        .onChange(of: refreshProgress) { _, newValue in
            // Rotation animation based on pull distance
            withAnimation(.linear(duration: 0.1)) {
                rotationAngle = newValue * 360
            }
            
            // When fully pulled, start continuous rotation
            if newValue >= 1.0 {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
        }
    }
}

#Preview {
    RefreshHeader(refreshProgress: 0.7)
        .background(Color.loopedBackground)
}