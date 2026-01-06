import SwiftUI

struct FeedNewPostsToast: View {
    let count: Int
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up")
                .font(.loopedSubBodyRegular)
            Text("\(count) new posts")
                .font(.loopedSubBodyRegular)
        }
        .foregroundColor(.loopedBackground)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.loopedContrast)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -24 {
                        onDismiss()
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
        )
        .onTapGesture { onTap() }
        .accessibilityLabel("\(count) new posts")
        .accessibilityHint("Tap to refresh. Swipe up to dismiss.")
    }
}
