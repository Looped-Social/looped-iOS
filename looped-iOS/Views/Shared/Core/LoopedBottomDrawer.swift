import SwiftUI

/// A lightweight, reusable bottom drawer that presents edge-to-edge on all iOS versions.
/// This avoids system sheet inset behavior on newer iOS versions for partial-height presentations.
struct LoopedBottomDrawer<Content: View>: View {
    let isPresented: Bool
    let onDismiss: () -> Void
    let content: Content

    @GestureState private var dragTranslation: CGFloat = 0

    init(
        isPresented: Bool,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isPresented = isPresented
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if isPresented {
                    Color.loopedBlack.opacity(0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture(perform: onDismiss)

                    drawer(bottomInset: proxy.safeAreaInsets.bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isPresented)
            .allowsHitTesting(isPresented)
            // Ensure the drawer can fully cover the home-indicator safe area.
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func drawer(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.loopedTextSecondary.opacity(0.22))
                .frame(width: 56, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            content
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.bottom, max(12, bottomInset))
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.loopedBackground)
        .ignoresSafeArea(edges: .bottom)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24
            )
        )
        .offset(y: max(0, dragTranslation))
        .gesture(dismissDragGesture)
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                if value.translation.height > 0 {
                    state = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 90 {
                    onDismiss()
                }
            }
    }
}
