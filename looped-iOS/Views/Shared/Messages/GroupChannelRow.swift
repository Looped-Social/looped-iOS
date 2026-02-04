import SwiftUI

struct GroupChannelRow: View {
    let channel: Channel

    var body: some View {
        HStack(spacing: 12) {
            GroupAvatarView(name: channel.name, photoUrl: channel.photoUrl, size: 50)

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
            photoUrl: nil,
            company: "",
            memberCount: 8,
            isPublic: false,
            createdAt: Date(),
            ownerUserId: 1,
            viewerCanManageMembers: true
        )
    )
}
