import SwiftUI

struct PullToRefreshScrollView<Content: View>: View {
    let options: PullToRefreshOptions
    let onRefresh: () async -> Void
    let onScrollChange: ((CGFloat) -> Void)?
    let content: Content
    
    @Binding var isRefreshing: Bool
    @State private var currentState: PullToRefreshState = .idle
    @State private var dragOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    @State private var canTriggerRefresh = true
    
    init(
        options: PullToRefreshOptions = PullToRefreshOptions(),
        isRefreshing: Binding<Bool>,
        onRefresh: @escaping () async -> Void,
        onScrollChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.options = options
        self._isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.onScrollChange = onScrollChange
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Pull-to-refresh animation header
                    PullToRefreshAnimationView(state: currentState, options: options)
                        .frame(maxWidth: .infinity)
                    
                    // Main content
                    content
                }
                .background(
                    GeometryReader { contentGeometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: contentGeometry.frame(in: .named("scrollView")).minY
                            )
                    }
                )
            }
            .coordinateSpace(name: "scrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                handleScrollOffset(offset)
            }
        }
        .onChange(of: isRefreshing) { _, newValue in
            if newValue {
                currentState = .refreshing
                performRefresh()
            } else {
                withAnimation(.easeOut(duration: options.animationDuration)) {
                    currentState = .idle
                }
            }
        }
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        let scrollDelta = offset - lastScrollOffset

        // Notify parent about scroll changes for header hiding
        // Pass the actual offset, not the delta
        onScrollChange?(offset)
        
        // Handle pull-to-refresh logic
        if !isRefreshing && offset > 0 {
            let progress = min(offset / options.threshold, 1.0)
            
            withAnimation(.easeOut(duration: 0.1)) {
                currentState = .pulling(progress: progress)
            }
            
            // Trigger refresh when threshold is reached
            if progress >= 1.0 && canTriggerRefresh && scrollDelta < 0 {
                triggerRefresh()
            }
        } else if !isRefreshing && offset <= 0 {
            withAnimation(.easeOut(duration: options.animationDuration)) {
                currentState = .idle
            }
        }
        
        lastScrollOffset = offset
    }
    
    private func triggerRefresh() {
        guard canTriggerRefresh && !isRefreshing else { return }
        
        canTriggerRefresh = false
        
        // Haptic feedback
        if options.hapticFeedback {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
        
        isRefreshing = true
    }
    
    private func performRefresh() {
        Task {
            await onRefresh()
            
            await MainActor.run {
                withAnimation(.easeOut(duration: options.animationDuration)) {
                    isRefreshing = false
                    canTriggerRefresh = true
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var isRefreshing = false
    
    return PullToRefreshScrollView(
        isRefreshing: $isRefreshing,
        onRefresh: {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    ) {
        LazyVStack(spacing: 0) {
            ForEach(0..<20, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Post \(index)")
                        .font(.headline)
                    Text("This is sample content for post \(index)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
    .background(Color.loopedBackground)
}