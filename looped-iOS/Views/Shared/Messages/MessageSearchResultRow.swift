import SwiftUI

struct MessageSearchResultRow: View {
    let hit: MessageSearchHit

    private var title: String {
        switch hit.type {
        case .conversation:
            return hit.conversation?.userName ?? "Conversation"
        case .channel:
            return hit.channel?.name ?? "Channel"
        }
    }

    private var avatar: some View {
        Group {
            switch hit.type {
            case .conversation:
                ProfileAvatarView(imageURL: hit.conversation?.userProfileImageUrl, size: 50)
            case .channel:
                Circle()
                    .fill(Color.loopedSecondary)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(channelInitials)
                            .font(.loopedCustom(.semibold, size: 16))
                            .foregroundColor(.loopedWhite)
                    )
            }
        }
    }

    private var channelInitials: String {
        let words = (hit.channel?.name ?? "").split(separator: " ")
        let initials = words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return initials.isEmpty ? "CH" : initials
    }

    private var timestampText: String? {
        guard let date = hit.previewTimestamp else { return nil }
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "H:mm"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "d/M"
        } else {
            formatter.dateFormat = "d/M/yy"
        }
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.loopedBodyStrong)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    if let timestampText {
                        Text(timestampText)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }

                Text(hit.previewText)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.loopedBackground)
    }
}

#Preview {
    MessageSearchResultRow(
        hit: MessageSearchHit(
            id: "conversation-1",
            type: .conversation,
            conversation: Conversation(
                userId: UUID(),
                userName: "Erin",
                userProfileImageUrl: nil,
                lastMessage: "Last message",
                lastMessageTimestamp: Date()
            ),
            channel: nil,
            matchedMessage: nil,
            previewText: "Matched message content…",
            previewTimestamp: Date()
        )
    )
}

