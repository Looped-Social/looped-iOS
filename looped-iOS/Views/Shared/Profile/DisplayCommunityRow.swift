import SwiftUI

struct DisplayCommunityRow: View {
    let displayCommunity: DisplayCommunity?
    let fallbackText: String
    var font: Font = .loopedSubBodyRegular
    var textColor: Color = .loopedTextSecondary
    var iconSize: CGFloat = 16
    var showsDisclosure: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            DisplayCommunityIcon(displayCommunity: displayCommunity, size: iconSize)

            Text(displayCommunity?.displayText ?? fallbackText)
                .font(font)
                .foregroundColor(textColor)

            Spacer()

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.loopedTextSecondary)
            }
        }
    }
}

private struct DisplayCommunityIcon: View {
    let displayCommunity: DisplayCommunity?
    let size: CGFloat

    var body: some View {
        if let displayCommunity {
            Circle()
                .fill(Color.loopedPrimary)
                .frame(width: size, height: size)
                .overlay(
                    Text(displayCommunity.initials)
                        .font(.system(size: max(10, size * 0.6), weight: .bold))
                        .foregroundColor(.white)
                )
        } else {
            Image(systemName: "xmark.seal")
                .font(.system(size: max(12, size)))
                .foregroundColor(.loopedTextSecondary)
        }
    }
}
