import SwiftUI

// MARK: - Full Screen Image Viewer
struct FullScreenImageViewer: View {
    let imageUrl: String
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Image with gestures
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    // Reset if zoomed out too far
                                    if scale < 1.0 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                    // Limit max zoom
                                    if scale > 4.0 {
                                        withAnimation(.spring()) {
                                            scale = 4.0
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Only allow panning when zoomed in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    } else {
                                        // When not zoomed, use drag to dismiss
                                        offset = CGSize(
                                            width: value.translation.width * 0.3,
                                            height: value.translation.height
                                        )
                                    }
                                }
                                .onEnded { value in
                                    if scale > 1.0 {
                                        lastOffset = offset
                                    } else {
                                        // Dismiss if dragged down enough
                                        if value.translation.height > 100 {
                                            isPresented = false
                                        } else {
                                            withAnimation(.spring()) {
                                                offset = .zero
                                            }
                                        }
                                    }
                                }
                        )
                        .onTapGesture {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    // Reset zoom
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    // Zoom in to 2x
                                    scale = 2.0
                                }
                            }
                        }

                case .failure(_):
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Failed to load image")
                            .foregroundColor(.white.opacity(0.7))
                    }

                case .empty:
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)

                @unknown default:
                    EmptyView()
                }
            }

            // Controls overlay
            if showControls {
                VStack {
                    // Top bar with close and share buttons
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }

                        Spacer()

                        Button(action: {
                            showShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                    }
                    .padding()

                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: !showControls)
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: imageUrl) {
                ShareSheet(items: [url])
            }
        }
    }
}

#Preview {
    FullScreenImageViewer(
        imageUrl: "https://via.placeholder.com/600",
        isPresented: .constant(true)
    )
}
