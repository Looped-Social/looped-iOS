import SwiftUI

struct SpecializationIcon: View {
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

                Text("\(memberCount) members")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
        SpecializationIcon(name: "Computer Science", memberCount: 1800)
        SpecializationIcon(name: "Business", memberCount: 2500)
        SpecializationIcon(name: "Marketing", memberCount: 1200)
        SpecializationIcon(name: "Design", memberCount: 760)
    }
    .padding()
    .background(Color.loopedBackground)
}
