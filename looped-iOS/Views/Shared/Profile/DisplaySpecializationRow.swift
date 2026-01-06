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

    var body: some View {
        HStack(spacing: 8) {
            if showsIcon {
                Image(systemName: isSelected ? "graduationcap.fill" : "graduationcap")
                    .font(.system(size: max(12, iconSize)))
                    .foregroundColor(textColor)
            }

            Text(displayText)
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

    private var displayText: String {
        let baseText = specializationName ?? fallbackText
        if let communityName, specializationName != nil || showsCommunityFallback {
            return "\(baseText) @ \(communityName)"
        }
        return baseText
    }

    private var isSelected: Bool {
        specializationName != nil
    }

    private var specializationName: String? {
        trimmed(specialization?.name)
    }

    private var communityName: String? {
        trimmed(displayCommunity?.name)
    }

    private func trimmed(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
