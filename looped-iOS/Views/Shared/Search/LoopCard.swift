import SwiftUI

struct LoopCard: View {
    let title: String
    let description: String
    let memberCount: Int

    var body: some View {
        VStack(spacing: 8) {
            // Profile icon circle - made larger
            Circle()
                .fill(Color.loopedMutedBackground)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: 32))
                        .foregroundColor(.loopedTextSecondary)
                )

            VStack(spacing: 4) {
                // Title - larger font
                Text(title)
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1)

                // Description - smaller than title
                Text(description)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Member count - smallest
                Text("\(memberCount) members")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(Color.loopedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.loopedMutedBackground, lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 16) {
        LoopCard(
            title: "Engineering",
            description: "Tech discussions and career tips",
            memberCount: 1250
        )

        LoopCard(
            title: "Design",
            description: "UX/UI design inspiration",
            memberCount: 890
        )

        LoopCard(
            title: "Marketing",
            description: "Growth and strategy insights",
            memberCount: 640
        )
    }
    .padding()
    .background(Color.loopedBackground)
}