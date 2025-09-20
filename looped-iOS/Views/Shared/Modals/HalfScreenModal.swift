import SwiftUI

struct HalfScreenModal<ModalContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let modalContent: () -> ModalContent
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                // Background overlay with dimming
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                
                // Modal content
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Modal handle
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.loopedTextSecondary.opacity(0.3))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        
                        // Content
                        self.modalContent()
                    }
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.7) // 70% of screen height
                    .background(Color.loopedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

extension View {
    func halfScreenModal<ModalContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> ModalContent
    ) -> some View {
        self.modifier(HalfScreenModal(isPresented: isPresented, modalContent: content))
    }
}