import SwiftUI

struct DisplaySpecializationRow: View {
    let specialization: DisplayCommunity?
    let displayCommunity: DisplayCommunity?
    let fallbackText: String
    var font: Font = .loopedSubBodyRegular
    var textColor: Color = .loopedTextSecondary
    var iconSize: CGFloat = 16
    var showsIcon: Bool = true
    var showsDisclosure: Bool = false
    var showsCommunityFallback: Bool = true
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames

    var body: some View {
        HStack(spacing: 8) {
            if showsIcon {
                Image(systemName: isSelected ? "graduationcap.fill" : "graduationcap")
                    .font(.loopedCustom(size: max(12, iconSize)))
                    .foregroundColor(textColor)
            }

            Text(displayText)
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

    private var displayText: String {
        let baseText = specializationLabel ?? fallbackText
        if let communityLabel, specializationLabel != nil || showsCommunityFallback {
            return "\(baseText) @ \(communityLabel)"
        }
        return baseText
    }

    private var isSelected: Bool {
        specializationLabel != nil
    }

    private var specializationLabel: String? {
        CommunityLabelText.preferredName(
            preferShortNames: preferCommunityShortNames,
            name: specialization?.name,
            shortName: specialization?.shortName
        )
    }

    private var communityLabel: String? {
        CommunityLabelText.preferredName(
            preferShortNames: preferCommunityShortNames,
            name: displayCommunity?.name,
            shortName: displayCommunity?.shortName
        )
    }
}
