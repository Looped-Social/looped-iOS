import SwiftUI
import Combine

class HeaderVisibilityManager: ObservableObject {
    @Published var isVisible: Bool = true
    @Published var scrollOffset: CGFloat = 0

    private var lastScrollOffset: CGFloat = 0
    private var scrollDirection: ScrollDirection = .none
    private let threshold: CGFloat = 15
    private let hideThreshold: CGFloat = 40
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
            .debounce(for: .milliseconds(10), scheduler: DispatchQueue.main)
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
        if newOffset >= -5 {
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = true
            }
            lastScrollOffset = newOffset
            return
        }

        // Hide header on ANY downward movement
        if delta < 0 {
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = false
            }
        } else if delta > 0 {
            // Show header on ANY upward movement
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