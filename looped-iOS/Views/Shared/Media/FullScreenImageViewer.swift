import SwiftUI

// MARK: - Full Screen Image Viewer
struct FullScreenImageViewer: View {
    let imageUrls: [String]
    let initialIndex: Int
    @Binding var isPresented: Bool

    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    @State private var showShareSheet = false

    init(imageUrls: [String], initialIndex: Int = 0, isPresented: Binding<Bool>) {
        self.imageUrls = imageUrls
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // TabView for swiping between images
            TabView(selection: $currentIndex) {
                ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, imageUrl in
                    SingleImageView(
                        imageUrl: imageUrl,
                        scale: $scale,
                        lastScale: $lastScale,
                        offset: $offset,
                        lastOffset: $lastOffset,
                        showControls: $showControls,
                        isPresented: $isPresented
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { oldValue, newValue in
                // Reset zoom when changing images
                withAnimation(.spring(duration: 0.3)) {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                    lastScale = 1.0
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

                        // Page indicator (if multiple images)
                        if imageUrls.count > 1 {
                            Text("\(currentIndex + 1) / \(imageUrls.count)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.5)))
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
            if let url = URL(string: imageUrls[currentIndex]) {
                ShareSheet(items: [url])
            }
        }
    }
}

// MARK: - Single Image View (within the TabView)
struct SingleImageView: View {
    let imageUrl: String
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var showControls: Bool
    @Binding var isPresented: Bool

    var body: some View {
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
                        DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                if scale > 1.0 {
                                    // When zoomed in, allow panning in all directions
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                } else {
                                    // When not zoomed, only handle vertical drags for dismiss
                                    // Let horizontal drags pass through to TabView for swiping
                                    let horizontalAmount = abs(value.translation.width)
                                    let verticalAmount = abs(value.translation.height)

                                    // Only handle if this is primarily a vertical drag
                                    if verticalAmount > horizontalAmount {
                                        offset = CGSize(
                                            width: 0,
                                            height: value.translation.height
                                        )
                                    }
                                }
                            }
                            .onEnded { value in
                                if scale > 1.0 {
                                    lastOffset = offset
                                } else {
                                    let horizontalAmount = abs(value.translation.width)
                                    let verticalAmount = abs(value.translation.height)

                                    // Only dismiss if this was primarily a vertical drag
                                    if verticalAmount > horizontalAmount && value.translation.height > 100 {
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
    }
}

#Preview("Single Image") {
    FullScreenImageViewer(
        imageUrls: ["https://via.placeholder.com/600"],
        isPresented: .constant(true)
    )
}

#Preview("Multiple Images") {
    FullScreenImageViewer(
        imageUrls: [
            "https://via.placeholder.com/600/FF0000",
            "https://via.placeholder.com/600/00FF00",
            "https://via.placeholder.com/600/0000FF"
        ],
        initialIndex: 1,
        isPresented: .constant(true)
    )
}
