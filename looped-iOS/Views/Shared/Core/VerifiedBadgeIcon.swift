import SwiftUI

struct VerifiedBadgeIcon: View {
    var tint: Color = .loopedSecondary
    var size: CGFloat = 16

    var body: some View {
        Image("verfied-icon")
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
