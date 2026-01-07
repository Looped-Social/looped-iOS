import SwiftUI

struct GroupIcon: View {
    let title: String
    let iconName: String
    let memberCount: Int

    var body: some View {
        VStack(spacing: 8) {
            // Icon circle
            Circle()
                .fill(Color.loopedMutedBackground)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: iconName)
                        .font(.loopedCustom(size: 20))
                        .foregroundColor(.loopedTextSecondary)
                )

            VStack(spacing: 2) {
                Text(title)
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
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
        GroupIcon(title: "Tech", iconName: "laptopcomputer", memberCount: 2500)
        GroupIcon(title: "Design", iconName: "paintbrush", memberCount: 1800)
        GroupIcon(title: "Business", iconName: "briefcase", memberCount: 3200)
        GroupIcon(title: "Finance", iconName: "chart.line.uptrend.xyaxis", memberCount: 1400)
        GroupIcon(title: "Sales", iconName: "phone", memberCount: 980)
        GroupIcon(title: "HR", iconName: "person.3", memberCount: 750)
        GroupIcon(title: "Legal", iconName: "scale.3d", memberCount: 420)
        GroupIcon(title: "Operations", iconName: "gear", memberCount: 1100)
    }
    .padding()
    .background(Color.loopedBackground)
}