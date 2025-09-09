import SwiftUI

enum PullToRefreshState {
    case idle
    case pulling(progress: CGFloat)
    case refreshing
}

struct PullToRefreshOptions {
    let threshold: CGFloat
    let animationDuration: Double
    let hapticFeedback: Bool
    
    init(threshold: CGFloat = 80, animationDuration: Double = 0.3, hapticFeedback: Bool = true) {
        self.threshold = threshold
        self.animationDuration = animationDuration
        self.hapticFeedback = hapticFeedback
    }
}