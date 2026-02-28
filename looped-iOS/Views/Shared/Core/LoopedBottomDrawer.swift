import SwiftUI

/// A lightweight, reusable bottom drawer that presents edge-to-edge on all iOS versions.
/// This avoids system sheet inset behavior on newer iOS versions for partial-height presentations.
struct LoopedBottomDrawer<Content: View>: View {
    let isPresented: Bool
    let onDismiss: () -> Void
    let backgroundColor: Color
    let content: Content

    @GestureState private var dragTranslation: CGFloat = 0

    init(
        isPresented: Bool,
        onDismiss: @escaping () -> Void,
        backgroundColor: Color = .loopedShareSheetBackground,
        @ViewBuilder content: () -> Content
    ) {
        self.isPresented = isPresented
        self.onDismiss = onDismiss
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.loopedBlack
                    .opacity(isPresented ? 0.45 : 0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        guard isPresented else { return }
                        onDismiss()
                    }
                    .animation(.easeOut(duration: 0.16), value: isPresented)

                drawer(bottomInset: proxy.safeAreaInsets.bottom)
                    .offset(y: drawerOffset(for: proxy))
                    .animation(
                        .interactiveSpring(
                            response: 0.22,
                            dampingFraction: 0.94,
                            blendDuration: 0.06
                        ),
                        value: isPresented
                    )
            }
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
        .background(backgroundColor)
        .ignoresSafeArea(edges: .bottom)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24
            )
        )
        .gesture(dismissDragGesture)
    }

    private func drawerOffset(for proxy: GeometryProxy) -> CGFloat {
        let hiddenOffset = proxy.size.height + proxy.safeAreaInsets.bottom + 32
        return (isPresented ? 0 : hiddenOffset) + max(0, dragTranslation)
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
