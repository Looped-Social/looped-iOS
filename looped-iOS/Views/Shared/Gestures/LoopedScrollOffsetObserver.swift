import SwiftUI
import UIKit

/// Reports normalized vertical offset from the enclosing `UIScrollView`.
/// Offset is `0` at the top, then negative as content scrolls down.
struct LoopedScrollOffsetObserver: UIViewRepresentable {
    let onOffsetChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onOffsetChange = onOffsetChange
        return view
    }

    func updateUIView(_ uiView: ObserverView, context: Context) {
        uiView.onOffsetChange = onOffsetChange
    }

    final class ObserverView: UIView {
        var onOffsetChange: ((CGFloat) -> Void)?

        private weak var observedScrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var adjustedInsetObservation: NSKeyValueObservation?
        private var lastEmittedOffset: CGFloat = .greatestFiniteMagnitude
        private var pendingOffset: CGFloat?
        private var isDispatchScheduled = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            installObservationIfNeeded()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installObservationIfNeeded()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            installObservationIfNeeded()
            emitCurrentOffsetIfNeeded()
        }

        deinit {
            clearObservation()
        }

        private func installObservationIfNeeded() {
            guard let scrollView = enclosingScrollView else { return }
            guard observedScrollView !== scrollView else { return }

            clearObservation()
            observedScrollView = scrollView
            if debugLogsEnabled {
                print("[FeedScroll] observer attached")
            }

            contentOffsetObservation = scrollView.observe(
                \.contentOffset,
                options: [.initial, .new]
            ) { [weak self] _, _ in
                self?.emitCurrentOffsetIfNeeded()
            }

            adjustedInsetObservation = scrollView.observe(
                \.adjustedContentInset,
                options: [.initial, .new]
            ) { [weak self] _, _ in
                self?.emitCurrentOffsetIfNeeded(force: true)
            }
        }

        private func clearObservation() {
            contentOffsetObservation = nil
            adjustedInsetObservation = nil
            observedScrollView = nil
            lastEmittedOffset = .greatestFiniteMagnitude
            pendingOffset = nil
            isDispatchScheduled = false
        }

        private func emitCurrentOffsetIfNeeded(force: Bool = false) {
            guard let scrollView = observedScrollView else { return }

            let normalizedOffset = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
            if !force, abs(normalizedOffset - lastEmittedOffset) < 0.25 {
                return
            }

            lastEmittedOffset = normalizedOffset
            enqueueOffsetDispatch(normalizedOffset)
        }

        private func enqueueOffsetDispatch(_ offset: CGFloat) {
            pendingOffset = offset
            guard !isDispatchScheduled else { return }
            isDispatchScheduled = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isDispatchScheduled = false
                guard let nextOffset = self.pendingOffset else { return }
                self.pendingOffset = nil
                self.onOffsetChange?(nextOffset)
            }
        }

        private var debugLogsEnabled: Bool {
            ProcessInfo.processInfo.environment["LOOPED_DEBUG_SCROLL_LOG"] == "1"
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
    }
}
