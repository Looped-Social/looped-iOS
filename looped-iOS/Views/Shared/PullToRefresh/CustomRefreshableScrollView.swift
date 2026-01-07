import SwiftUI

struct CustomRefreshableScrollView<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void
    let onScrollChange: ((CGFloat) -> Void)?
    
    @State private var refreshProgress: CGFloat = 0
    @State private var isRefreshing = false
    @State private var scrollOffset: CGFloat = 0
    @State private var lastContentOffset: CGFloat = 0
    
    private let refreshThreshold: CGFloat = 80
    
    init(@ViewBuilder content: () -> Content, onRefresh: @escaping () async -> Void, onScrollChange: ((CGFloat) -> Void)? = nil) {
        self.content = content()
        self.onRefresh = onRefresh
        self.onScrollChange = onScrollChange
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Custom refresh header
                if refreshProgress > 0 {
                    RefreshHeader(refreshProgress: refreshProgress)
                        .offset(y: -refreshThreshold + (refreshProgress * refreshThreshold))
                }
                
                // Main content
                content
            }
        }
        .background(
            GeometryReader { geometry in
                Color.loopedClear
                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
            }
        )
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            DispatchQueue.main.async {
                handleScrollOffset(offset)
            }
        }
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        if isRefreshing { return }
        
        let pullDistance = max(0, offset)
        refreshProgress = min(1.0, pullDistance / refreshThreshold)
        
        // Notify parent about scroll changes
        let scrollDelta = offset - lastContentOffset
        if abs(scrollDelta) > 5 { // Minimum threshold to prevent jitter
            onScrollChange?(scrollDelta)
            lastContentOffset = offset
        }
        
        // Trigger refresh when threshold is reached and user releases
        if pullDistance >= refreshThreshold && offset <= 0 {
            triggerRefresh()
        }
    }
    
    private func triggerRefresh() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        refreshProgress = 1.0
        
        Task {
            await onRefresh()
            
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    refreshProgress = 0
                    isRefreshing = false
                }
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    CustomRefreshableScrollView(
        content: {
            LazyVStack {
                ForEach(0..<20, id: \.self) { i in
                    Text("Item \(i)")
                        .padding()
                        .background(Color.loopedGray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
        },
        onRefresh: {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
        }
    )
}