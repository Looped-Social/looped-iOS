import SwiftUI
import Combine

class HeaderVisibilityManager: ObservableObject {
    @Published var isVisible: Bool = true
    @Published var scrollOffset: CGFloat = 0

    private var lastScrollOffset: CGFloat = 0
    private var scrollDirection: ScrollDirection = .none
    private let threshold: CGFloat = 30
    private let hideThreshold: CGFloat = 80
    private var cancellables = Set<AnyCancellable>()

    enum ScrollDirection {
        case up, down, none
    }

    init() {
        setupScrollHandling()
    }

    private func setupScrollHandling() {
        $scrollOffset
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] offset in
                self?.handleScrollChange(offset)
            }
            .store(in: &cancellables)
    }

    func updateScrollOffset(_ newOffset: CGFloat) {
        scrollOffset = newOffset
    }

    private func handleScrollChange(_ newOffset: CGFloat) {
        let delta = newOffset - lastScrollOffset

        // Show header when at or near the top
        if newOffset >= -10 {
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = true
            }
            lastScrollOffset = newOffset
            return
        }

        // Only process significant scroll changes
        if abs(delta) < 10 {
            return
        }

        // Determine scroll direction
        if delta < -threshold && newOffset < -hideThreshold {
            // Scrolling down significantly - hide header
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = false
            }
        } else if delta > threshold {
            // Scrolling up significantly - show header
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = true
            }
        }

        lastScrollOffset = newOffset
    }

    private func updateVisibility(offset: CGFloat, delta: CGFloat, directionChanged: Bool) {
        // This method is no longer used - simplified logic in handleScrollChange
    }

    func reset() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible = true
        }
        lastScrollOffset = 0
        scrollOffset = 0
        scrollDirection = .none
    }

    func forceShow() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible = true
        }
    }

    func forceHide() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible = false
        }
    }
}