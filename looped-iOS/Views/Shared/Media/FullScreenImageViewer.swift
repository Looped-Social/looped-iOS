import SwiftUI

// MARK: - Full Screen Image Viewer
struct FullScreenImageViewer: View {
    let imageUrls: [String]
    let initialIndex: Int
    @Binding var isPresented: Bool
    let postActionConfig: PostActionBarConfig?

    @State private var currentIndex: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    @State private var showShareSheet = false

    init(imageUrls: [String], initialIndex: Int = 0, isPresented: Binding<Bool>, postActionConfig: PostActionBarConfig? = nil) {
        self.imageUrls = imageUrls
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self.postActionConfig = postActionConfig
        let clamped = min(max(initialIndex, 0), max(imageUrls.count - 1, 0))
        self._currentIndex = State(initialValue: clamped)
    }

    var body: some View {
        ZStack {
            // Background
            Color.loopedBlack
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
                        LoopedCloseButton(
                            action: { isPresented = false },
                            foregroundColor: .loopedWhite,
                            iconSize: 20,
                            hitArea: 44,
                            showsBackground: true,
                            backgroundColor: .loopedBlack,
                            backgroundOpacity: 0.5
                        )

                        Spacer()

                        // Page indicator (if multiple images)
                        if imageUrls.count > 1 {
                            Text("\(currentIndex + 1) / \(imageUrls.count)")
                                .font(.loopedCustom(.semibold, size: 16))
                                .foregroundColor(.loopedWhite)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 20).fill(Color.loopedBlack.opacity(0.5)))
                        }

                        Spacer()

                        Button(action: {
                            showShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.loopedCustom(.semibold, size: 20))
                                .foregroundColor(.loopedWhite)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.loopedBlack.opacity(0.5)))
                        }
                    }
                    .padding()

                    Spacer()

                    if let config = actionBarConfig {
                        PostActionBarCompact(config: config, sizeScale: 1.3)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: !showControls)
        .onAppear {
            syncToInitialIndex()
        }
        .onChange(of: initialIndex) { _, _ in
            syncToInitialIndex()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: imageUrls[currentIndex]) {
                ShareSheet(items: [url])
            }
        }
    }

    private var actionBarConfig: PostActionBarConfig? {
        guard let base = postActionConfig else { return nil }
        return PostActionBarConfig(
            state: base.state,
            onLike: base.onLike,
            onComment: {
                isPresented = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    base.onComment()
                }
            },
            onRepost: base.onRepost,
            onShare: base.onShare,
            onSave: base.onSave
        )
    }

    private func syncToInitialIndex() {
        guard !imageUrls.isEmpty else {
            currentIndex = 0
            return
        }

        let clamped = min(max(initialIndex, 0), imageUrls.count - 1)
        currentIndex = clamped
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
        showControls = true
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
    @State private var isShimmering = true

    var body: some View {
        LoopedDownsampledAsyncImage(
            url: URL.loopedMediaURL(from: imageUrl),
            maxPixelSize: 3072
        ) { phase in
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
                    .onAppear {
                        isShimmering = false
                    }

            case .failure:
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.loopedCustom(size: 60))
                        .foregroundColor(.loopedWhite.opacity(0.5))
                    Text("Failed to load image")
                        .foregroundColor(.loopedWhite.opacity(0.7))
                }

            case .empty:
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.loopedMutedBackground.opacity(0.25))
                    .frame(width: 240, height: 240)
                    .overlay {
                        ProgressView()
                            .tint(.loopedWhite.opacity(0.7))
                    }
                    .shimmering(isShimmering)
                    .task {
                        await stopShimmerAfterDelay()
                    }
            }
        }
    }

    private func stopShimmerAfterDelay() async {
        guard isShimmering else { return }
        try? await Task.sleep(nanoseconds: 1_800_000_000)
        isShimmering = false
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
