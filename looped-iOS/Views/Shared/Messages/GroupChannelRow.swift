import SwiftUI

struct GroupChannelRow: View {
    let channel: Channel

    private var groupInitials: String {
        let words = channel.name.split(separator: " ")
        let initials = words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return initials.isEmpty ? "GC" : initials
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.loopedSecondary)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(groupInitials)
                        .font(.loopedCustom(.semibold, size: 16))
                        .foregroundColor(.loopedWhite)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.loopedBodyStrong)
                    .foregroundColor(.loopedTextPrimary)

                Text("\(channel.memberCount) members")
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.loopedBackground)
    }
}

#Preview {
    GroupChannelRow(
        channel: Channel(
            id: UUID(),
            backendId: 1,
            name: "Marketing Team",
            company: "",
            memberCount: 8,
            isPublic: false,
            createdAt: Date(),
            ownerUserId: 1,
            viewerCanManageMembers: true
        )
    )
}
