import SwiftUI

private enum LoopedPullToRefreshConstants {
    static let threshold: CGFloat = 90
    static let completionFadeDelayNanoseconds: UInt64 = 220_000_000
}

struct LoopedPullToRefreshModifier: ViewModifier {
    let isEnabled: Bool
    let isAtTop: Bool
    let indicatorTopPadding: CGFloat
    let onRefresh: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var pullTranslation: CGFloat = 0
    @State private var phase: LoopedPullToRefreshIndicator.Phase?

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($pullTranslation) { value, state, _ in
                        guard shouldTrackPull else { return }
                        state = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        guard shouldTrackPull else { return }
                        guard phase == nil else { return }
                        if value.translation.height >= LoopedPullToRefreshConstants.threshold {
                            startRefresh()
                        }
                    }
            )
            .overlay(alignment: .top) {
                if let indicatorPhase = indicatorPhase {
                    LoopedPullToRefreshIndicator(
                        fillProgress: fillProgress,
                        stretchProgress: stretchProgress,
                        phase: indicatorPhase
                    )
                    .padding(.top, indicatorTopPadding)
                    .transition(.opacity)
                }
            }
    }

    private var shouldTrackPull: Bool {
        isEnabled && isAtTop && phase == nil
    }

    private var indicatorPhase: LoopedPullToRefreshIndicator.Phase? {
        if let phase {
            return phase
        }
        guard isEnabled && isAtTop else { return nil }
        return pullTranslation > 1 ? .pulling : nil
    }

    private var fillProgress: CGFloat {
        if phase != nil {
            return 1
        }
        let progress = max(0, pullTranslation) / LoopedPullToRefreshConstants.threshold
        return min(1, progress)
    }

    private var stretchProgress: CGFloat {
        if phase != nil {
            return 1
        }
        let progress = max(0, pullTranslation) / LoopedPullToRefreshConstants.threshold
        return min(1.6, progress)
    }

    private func startRefresh() {
        phase = .refreshing

        Task {
            await onRefresh()
            await MainActor.run {
                phase = .completing
            }
            if reduceMotion {
                await MainActor.run {
                    phase = nil
                }
                return
            }
            try? await Task.sleep(nanoseconds: LoopedPullToRefreshConstants.completionFadeDelayNanoseconds)
            await MainActor.run {
                phase = nil
            }
        }
    }
}

extension View {
    func loopedPullToRefresh(
        isEnabled: Bool = true,
        isAtTop: Bool = true,
        indicatorTopPadding: CGFloat = 16,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        modifier(
            LoopedPullToRefreshModifier(
                isEnabled: isEnabled,
                isAtTop: isAtTop,
                indicatorTopPadding: indicatorTopPadding,
                onRefresh: onRefresh
            )
        )
    }
}

