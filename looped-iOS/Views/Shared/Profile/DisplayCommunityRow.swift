import SwiftUI

struct DisplayCommunityRow: View {
    let displayCommunity: DisplayCommunity?
    let fallbackText: String
    var font: Font = .loopedSubBodyRegular
    var textColor: Color = .loopedTextSecondary
    var iconSize: CGFloat = 16
    var showsIcon: Bool = true
    var showsDisclosure: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if showsIcon {
                DisplayCommunityIcon(
                    isSelected: displayCommunity != nil,
                    size: iconSize,
                    color: textColor
                )
            }

            Text(displayCommunity?.displayText ?? fallbackText)
                .font(font)
                .foregroundColor(textColor)

            Spacer()

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.loopedCustom(.semibold, size: 12))
                    .foregroundColor(.loopedTextSecondary)
            }
        }
    }
}

private struct DisplayCommunityIcon: View {
    let isSelected: Bool
    let size: CGFloat
    let color: Color

    var body: some View {
        Image(systemName: isSelected ? "briefcase.fill" : "briefcase")
            .font(.loopedCustom(size: max(12, size)))
            .foregroundColor(color)
    }
}
