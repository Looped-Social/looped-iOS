import SwiftUI
import UIKit
import QuartzCore

private enum LoopedPullToRefreshConstants {
    static let threshold: CGFloat = 90
    static let activationDistance: CGFloat = 10
    static let legacyVisualStartThreshold: CGFloat = 4
    static let completionFadeDelayNanoseconds: UInt64 = 220_000_000
}

struct LoopedPullToRefreshModifier: ViewModifier {
    let isEnabled: Bool
    let isAtTop: Bool
    let indicatorTopPadding: CGFloat
    let showsIndicatorOverlay: Bool
    let indicatorState: Binding<LoopedPullToRefreshIndicatorState?>?
    let onRefresh: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var pullTranslation: CGFloat = 0
    @State private var phase: LoopedPullToRefreshIndicator.Phase?
    @State private var legacyIsAtTop = true
    @State private var legacyPullDistance: CGFloat = 0
    @State private var legacyIsDragging = false
    @State private var legacyVisualStarted = false
    @State private var legacyStartedFromTop = false
    @State private var lastRefreshDebugSignature: String = ""

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            modernBody(content: content)
        } else {
            legacyBody(content: content)
        }
    }

    private func modernBody(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: LoopedPullToRefreshConstants.activationDistance)
                    .updating($pullTranslation) { value, state, _ in
                        guard shouldTrackPull else { return }
                        let vertical = value.translation.height
                        let horizontal = abs(value.translation.width)
                        guard vertical > 0, abs(vertical) > horizontal else { return }
                        state = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        guard shouldTrackPull else { return }
                        guard phase == nil else { return }
                        let vertical = value.translation.height
                        let horizontal = abs(value.translation.width)
                        guard vertical > 0, abs(vertical) > horizontal else { return }
                        if value.translation.height >= LoopedPullToRefreshConstants.threshold {
                            startRefresh()
                        }
                    }
            )
            .onAppear {
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "appear")
            }
            .onChange(of: pullTranslation) { _, _ in
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "pull")
            }
            .onChange(of: phase) { _, _ in
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "phase")
            }
            .onChange(of: isAtTop) { _, _ in
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "top")
            }
            .onChange(of: isEnabled) { _, _ in
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "enabled")
            }
            .overlay(alignment: .top) {
                Group {
                    if showsIndicatorOverlay, let indicatorPhase = indicatorPhase {
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
            .overlay(alignment: .topLeading) {
                if showsRefreshDebugOverlay {
                    refreshDebugOverlay
                        .padding(.top, max(8, indicatorTopPadding + 18))
                        .padding(.leading, 10)
                }
            }
    }

    @ViewBuilder
    private func legacyBody(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: LoopedPullToRefreshConstants.activationDistance)
                    .updating($pullTranslation) { value, state, _ in
                        guard isEnabled else { return }
                        guard phase == nil else { return }
                        let vertical = value.translation.height
                        let horizontal = abs(value.translation.width)
                        guard vertical > 0, abs(vertical) > horizontal else { return }
                        state = max(0, vertical)
                    }
            )
            .background(
                LoopedLegacyRefreshControlHost(
                    isEnabled: isEnabled,
                    onTopChange: { atTop in
                        legacyIsAtTop = atTop
                    },
                    onRefresh: {
                        await handleLegacyRefreshControlTriggered()
                    }
                )
            )
            .onAppear {
                legacyIsAtTop = isAtTop
                if !isEnabled {
                    resetIndicatorState()
                    emitRefreshDebugIfNeeded(source: "disabled-appear")
                } else {
                    publishIndicatorState()
                    emitRefreshDebugIfNeeded(source: "appear")
                }
            }
            .onChange(of: pullTranslation) { oldValue, newValue in
                handleLegacyPullTransition(previous: oldValue, current: newValue)
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "pull")
            }
            .onChange(of: legacyIsDragging) { _, _ in
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "drag")
            }
            .onChange(of: legacyVisualStarted) { _, _ in
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "armed")
            }
            .onChange(of: phase) { _, _ in
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "phase")
            }
            .onChange(of: isAtTop) { _, _ in
                legacyIsAtTop = isAtTop
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "top")
            }
            .onChange(of: legacyIsAtTop) { _, _ in
                publishIndicatorState()
                emitRefreshDebugIfNeeded(source: "legacy-top")
            }
            .onChange(of: isEnabled) { _, enabled in
                if !enabled {
                    resetIndicatorState()
                } else {
                    publishIndicatorState()
                }
                emitRefreshDebugIfNeeded(source: "enabled")
            }
            .overlay(alignment: .top) {
                Group {
                    if showsIndicatorOverlay, let indicatorPhase = indicatorPhase {
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
            .overlay(alignment: .topLeading) {
                if showsRefreshDebugOverlay {
                    refreshDebugOverlay
                        .padding(.top, max(8, indicatorTopPadding + 18))
                        .padding(.leading, 10)
                }
            }
    }

    private var effectiveTopState: Bool {
        if #available(iOS 18.0, *) {
            return isAtTop
        }
        return isAtTop
    }

    private var currentPullDistance: CGFloat {
        if #available(iOS 18.0, *) {
            return pullTranslation
        }
        return legacyPullDistance
    }

    private var shouldTrackPull: Bool {
        if #available(iOS 18.0, *) {
            return isEnabled && phase == nil && (effectiveTopState || pullTranslation > 0)
        }
        return isEnabled && phase == nil && (effectiveTopState || legacyIsDragging || legacyVisualStarted)
    }

    private var indicatorPhase: LoopedPullToRefreshIndicator.Phase? {
        if let phase {
            return phase
        }
        if #available(iOS 18.0, *) {
            guard isEnabled && (effectiveTopState || pullTranslation > 0) else { return nil }
            return pullTranslation > 1 ? .pulling : nil
        }
        guard isEnabled else { return nil }
        guard legacyVisualStarted || (legacyIsDragging && legacyPullDistance > 1) else { return nil }
        return .pulling
    }

    private var fillProgress: CGFloat {
        if phase != nil {
            return 1
        }
        let progress = max(0, currentPullDistance) / LoopedPullToRefreshConstants.threshold
        return min(1, progress)
    }

    private var stretchProgress: CGFloat {
        if phase != nil {
            return 1
        }
        let progress = max(0, currentPullDistance) / LoopedPullToRefreshConstants.threshold
        return min(1.6, progress)
    }

    private func startRefresh() {
        phase = .refreshing

        Task {
            await onRefresh()
            await MainActor.run {
                phase = .completing
                publishIndicatorState()
            }
            if reduceMotion {
                await MainActor.run {
                    phase = nil
                    publishIndicatorState()
                }
                return
            }
            try? await Task.sleep(nanoseconds: LoopedPullToRefreshConstants.completionFadeDelayNanoseconds)
            await MainActor.run {
                phase = nil
                publishIndicatorState()
            }
        }
    }

    private func handleLegacyRefreshControlTriggered() async {
        guard isEnabled else { return }
        if showsRefreshDebugConsole {
            print("[PullRefreshControl] trigger top=\(effectiveTopState ? "1" : "0")")
        }

        let started = await MainActor.run { () -> Bool in
            guard phase == nil else { return false }
            resetLegacyGestureState()
            phase = .refreshing
            publishIndicatorState()
            return true
        }
        guard started else { return }

        await onRefresh()

        await MainActor.run {
            phase = .completing
            publishIndicatorState()
        }
        if !reduceMotion {
            try? await Task.sleep(nanoseconds: LoopedPullToRefreshConstants.completionFadeDelayNanoseconds)
        }
        await MainActor.run {
            phase = nil
            resetLegacyGestureState()
            publishIndicatorState()
        }
    }

    private func handleLegacyPullTransition(previous: CGFloat, current: CGFloat) {
        guard isEnabled else {
            resetLegacyGestureState()
            return
        }
        guard phase == nil else { return }

        let previousPull = max(0, previous)
        let currentPull = max(0, current)
        let wasDragging = previousPull > 0.5
        let isDraggingNow = currentPull > 0.5

        if !wasDragging, isDraggingNow {
            legacyStartedFromTop = effectiveTopState
        }

        legacyIsDragging = isDraggingNow
        legacyPullDistance = currentPull

        if currentPull >= LoopedPullToRefreshConstants.legacyVisualStartThreshold {
            legacyVisualStarted = true
        }

        let released = wasDragging && !isDraggingNow
        guard released else { return }

        let shouldTrigger = legacyVisualStarted && (legacyStartedFromTop || effectiveTopState)
        if showsRefreshDebugConsole {
            print("[PullRefresh] release source=gesture trigger=\(shouldTrigger ? "1" : "0")")
        }

        if shouldTrigger {
            Task { await handleLegacyRefreshControlTriggered() }
        } else {
            resetLegacyGestureState()
        }
    }

    private func resetLegacyGestureState() {
        legacyIsDragging = false
        legacyPullDistance = 0
        legacyVisualStarted = false
        legacyStartedFromTop = false
    }

    private func publishIndicatorState() {
        guard let indicatorState else { return }
        guard let indicatorPhase else {
            if indicatorState.wrappedValue != nil {
                indicatorState.wrappedValue = nil
            }
            return
        }

        let next = LoopedPullToRefreshIndicatorState(
            fillProgress: fillProgress,
            stretchProgress: stretchProgress,
            phase: indicatorPhase
        )
        if indicatorState.wrappedValue != next {
            indicatorState.wrappedValue = next
        }
    }

    private func resetIndicatorState() {
        phase = nil
        resetLegacyGestureState()
        if let indicatorState, indicatorState.wrappedValue != nil {
            indicatorState.wrappedValue = nil
        }
        emitRefreshDebugIfNeeded(source: "reset")
    }

    private var showsRefreshDebugOverlay: Bool {
        if #available(iOS 18.0, *) { return false }
#if DEBUG
        return ProcessInfo.processInfo.environment["LOOPED_DEBUG_REFRESH"] == "1"
#else
        return ProcessInfo.processInfo.environment["LOOPED_DEBUG_REFRESH"] == "1"
#endif
    }

    private var showsRefreshDebugConsole: Bool {
        if #available(iOS 18.0, *) { return false }
#if DEBUG
        return ProcessInfo.processInfo.environment["LOOPED_DEBUG_REFRESH_LOG"] == "1"
#else
        return ProcessInfo.processInfo.environment["LOOPED_DEBUG_REFRESH_LOG"] == "1"
#endif
    }

    @ViewBuilder
    private var refreshDebugOverlay: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("r-top: \(effectiveTopState ? "1" : "0")")
            Text("r-topV: \(isAtTop ? "1" : "0")")
            Text("r-topS: \(legacyIsAtTop ? "1" : "0")")
            Text("r-en: \(isEnabled ? "1" : "0")")
            Text("r-track: \(shouldTrackPull ? "1" : "0")")
            Text("r-pull: \(debugInt(currentPullDistance))")
            Text("r-drag: \(legacyIsDragging ? "1" : "0")")
            Text("r-vis: \(legacyVisualStarted ? "1" : "0")")
            Text("r-phase: \(debugPhaseLabel)")
        }
        .font(.loopedSmallText)
        .foregroundColor(.loopedBackground)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.loopedTextPrimary.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .allowsHitTesting(false)
    }

    private var debugPhaseLabel: String {
        guard let phase = indicatorPhase else { return "nil" }
        switch phase {
        case .pulling:
            return "pull"
        case .refreshing:
            return "refresh"
        case .completing:
            return "done"
        }
    }

    private func emitRefreshDebugIfNeeded(source: String) {
        guard showsRefreshDebugConsole else { return }
        let signature = "\(source)|\(effectiveTopState)|\(isAtTop)|\(legacyIsAtTop)|\(isEnabled)|\(legacyIsDragging)|\(legacyVisualStarted)|\(debugInt((currentPullDistance / 6).rounded()))|\(debugPhaseLabel)"
        guard signature != lastRefreshDebugSignature else { return }
        lastRefreshDebugSignature = signature
        print(
            "[PullRefresh] \(source) top=\(effectiveTopState) topV=\(isAtTop) topS=\(legacyIsAtTop) " +
            "enabled=\(isEnabled) track=\(shouldTrackPull) pull=\(debugInt(currentPullDistance)) " +
            "drag=\(legacyIsDragging) vis=\(legacyVisualStarted) phase=\(debugPhaseLabel)"
        )
    }

    private func debugInt(_ value: CGFloat) -> Int {
        guard value.isFinite else { return 0 }
        return Int(value.rounded(.towardZero))
    }
}

private struct LoopedLegacyRefreshControlHost: UIViewRepresentable {
    let isEnabled: Bool
    let onTopChange: (Bool) -> Void
    let onRefresh: () async -> Void

    func makeUIView(context: Context) -> HostingView {
        let view = HostingView()
        view.configure(
            isEnabled: isEnabled,
            onTopChange: onTopChange,
            onRefresh: onRefresh
        )
        return view
    }

    func updateUIView(_ uiView: HostingView, context: Context) {
        uiView.configure(
            isEnabled: isEnabled,
            onTopChange: onTopChange,
            onRefresh: onRefresh
        )
    }

    final class HostingView: UIView {
        private weak var observedScrollView: UIScrollView?
        private let refreshControl = UIRefreshControl()
        private var refreshTask: Task<Void, Never>?
        private var onRefresh: (() async -> Void)?
        private var onTopChange: ((Bool) -> Void)?
        private var isRefreshEnabled = true
        private var lastRefreshEndedAt: CFTimeInterval = 0
        private var contentOffsetObservation: NSKeyValueObservation?
        private var adjustedInsetObservation: NSKeyValueObservation?
        private var lastTopState: Bool?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = false
            refreshControl.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            refreshTask?.cancel()
            contentOffsetObservation = nil
            adjustedInsetObservation = nil
            refreshControl.removeTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            attachRefreshControlIfNeeded()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachRefreshControlIfNeeded()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            attachRefreshControlIfNeeded()
            emitTopStateIfNeeded()
        }

        func configure(
            isEnabled: Bool,
            onTopChange: @escaping (Bool) -> Void,
            onRefresh: @escaping () async -> Void
        ) {
            isRefreshEnabled = isEnabled
            self.onTopChange = onTopChange
            self.onRefresh = onRefresh
            refreshControl.isEnabled = false
            refreshControl.tintColor = .clear
            attachRefreshControlIfNeeded()
            emitTopStateIfNeeded(force: true)

            if !isEnabled {
                refreshTask?.cancel()
                refreshTask = nil
            }
        }

        @objc
        private func handleRefreshControl() {
            if debugLogsEnabled {
                print("[PullRefreshControl] valueChanged enabled=\(isRefreshEnabled ? "1" : "0")")
            }
            guard isRefreshEnabled else {
                refreshControl.endRefreshing()
                return
            }

            let now = CACurrentMediaTime()
            let minimumRearmInterval: CFTimeInterval = 0.45
            if now - lastRefreshEndedAt < minimumRearmInterval {
                if debugLogsEnabled {
                    print("[PullRefreshControl] suppressed cooldown=\(minimumRearmInterval)s")
                }
                refreshControl.endRefreshing()
                return
            }

            guard refreshTask == nil else { return }
            refreshTask = Task { [weak self] in
                guard let self else { return }
                if let onRefresh = self.onRefresh {
                    await onRefresh()
                }
                await MainActor.run {
                    self.refreshControl.endRefreshing()
                    self.refreshTask = nil
                    self.lastRefreshEndedAt = CACurrentMediaTime()
                    if self.debugLogsEnabled {
                        print("[PullRefreshControl] endRefreshing")
                    }
                    self.emitTopStateIfNeeded(force: true)
                }
            }
        }

        private func attachRefreshControlIfNeeded() {
            guard let scrollView = enclosingScrollView else { return }
            if observedScrollView !== scrollView {
                observedScrollView = scrollView
                attachObservers(to: scrollView)
            }
            if scrollView.bounces == false {
                scrollView.bounces = true
            }
            if scrollView.alwaysBounceVertical == false {
                scrollView.alwaysBounceVertical = true
            }
        }

        private func attachObservers(to scrollView: UIScrollView) {
            contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] _, _ in
                self?.emitTopStateIfNeeded()
            }
            adjustedInsetObservation = scrollView.observe(\.adjustedContentInset, options: [.initial, .new]) { [weak self] _, _ in
                self?.emitTopStateIfNeeded(force: true)
            }
        }

        private func emitTopStateIfNeeded(force: Bool = false) {
            guard let scrollView = observedScrollView else { return }
            let topEdge = -scrollView.adjustedContentInset.top
            let atTop = scrollView.contentOffset.y <= (topEdge + 1)
            if force || lastTopState != atTop {
                lastTopState = atTop
                onTopChange?(atTop)
                if debugLogsEnabled {
                    print(
                        "[PullRefreshTop] top=\(atTop ? "1" : "0") " +
                        "y=\(debugInt(scrollView.contentOffset.y)) inset=\(debugInt(scrollView.adjustedContentInset.top))"
                    )
                }
            }
        }

        private var enclosingScrollView: UIScrollView? {
            var current = superview
            while let view = current {
                if let scrollView = view as? UIScrollView {
                    return scrollView
                }
                current = view.superview
            }
            return nil
        }

        private func debugInt(_ value: CGFloat) -> Int {
            guard value.isFinite else { return 0 }
            return Int(value.rounded(.towardZero))
        }

        private var debugLogsEnabled: Bool {
#if DEBUG
            return ProcessInfo.processInfo.environment["LOOPED_DEBUG_REFRESH_LOG"] == "1"
#else
            return ProcessInfo.processInfo.environment["LOOPED_DEBUG_REFRESH_LOG"] == "1"
#endif
        }
    }
}

struct LoopedPullToRefreshIndicatorState: Equatable {
    let fillProgress: CGFloat
    let stretchProgress: CGFloat
    let phase: LoopedPullToRefreshIndicator.Phase
}

extension View {
    func loopedPullToRefresh(
        isEnabled: Bool = true,
        isAtTop: Bool = true,
        indicatorTopPadding: CGFloat = 16,
        showsIndicatorOverlay: Bool = true,
        indicatorState: Binding<LoopedPullToRefreshIndicatorState?>? = nil,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        modifier(
            LoopedPullToRefreshModifier(
                isEnabled: isEnabled,
                isAtTop: isAtTop,
                indicatorTopPadding: indicatorTopPadding,
                showsIndicatorOverlay: showsIndicatorOverlay,
                indicatorState: indicatorState,
                onRefresh: onRefresh
            )
        )
    }
}
