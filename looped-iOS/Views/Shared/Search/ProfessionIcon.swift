import SwiftUI

struct ProfessionIcon: View {
    let name: String
    let memberCount: Int

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.loopedMutedBackground)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(initials)
                        .font(.loopedCustom(.semibold, size: 18))
                        .foregroundColor(.loopedTextSecondary)
                )

            VStack(spacing: 2) {
                Text(name)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1)

                Text("\(memberCount)")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .frame(width: 80)
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
        ProfessionIcon(name: "Design", memberCount: 1800)
        ProfessionIcon(name: "Engineering", memberCount: 2500)
        ProfessionIcon(name: "Marketing", memberCount: 1200)
        ProfessionIcon(name: "HR", memberCount: 760)
    }
    .padding()
    .background(Color.loopedBackground)
}
