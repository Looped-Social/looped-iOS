import SwiftUI

struct SpecializationIcon: View {
    let name: String
    let memberCount: Int
    let specializationType: CommunitySpecializationType?

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.loopedMutedBackground.opacity(0.12))
                .frame(width: 50, height: 50)
                .overlay { glyphView }
                .overlay(
                    Circle()
                        .stroke(Color.loopedMutedBackground, lineWidth: 1)
                )

            VStack(spacing: 2) {
                Text(name)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1)

                Text("\(memberCount) members")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: 80)
    }

    private var glyphView: some View {
        Group {
            if let emoji {
                Text(emoji)
                    .font(.loopedCustom(.semibold, size: 26))
                    .foregroundColor(.loopedTextPrimary)
            } else {
                Text(initials)
                    .font(.loopedCustom(.semibold, size: 24))
                    .foregroundColor(.loopedPrimary)
            }
        }
    }

    private var emoji: String? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if normalized.contains("computer science")
            || normalized.contains("cs ")
            || normalized.hasPrefix("cs") {
            return "💻"
        }
        if normalized.contains("investment")
            || normalized.contains("banking")
            || normalized.contains("ib ") {
            return "📈"
        }
        if normalized.contains("finance") {
            return "💰"
        }
        if normalized.contains("engineering") {
            return "⚙️"
        }
        if normalized.contains("design") || normalized.contains("ux") || normalized.contains("ui") {
            return "🎨"
        }
        if normalized.contains("marketing") {
            return "📣"
        }
        if normalized.contains("sales") {
            return "🤝"
        }
        if normalized.contains("product") {
            return "📦"
        }

        switch specializationType {
        case .major:
            return "🎓"
        case .field:
            return "🏷️"
        default:
            return nil
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        let combined = (first + second).uppercased()
        return combined.isEmpty ? "?" : combined
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
        SpecializationIcon(name: "Computer Science", memberCount: 1800, specializationType: .major)
        SpecializationIcon(name: "Business", memberCount: 2500, specializationType: .major)
        SpecializationIcon(name: "Marketing", memberCount: 1200, specializationType: .field)
        SpecializationIcon(name: "Design", memberCount: 760, specializationType: .field)
    }
    .padding()
    .background(Color.loopedBackground)
}
