import SwiftUI

struct DrawerMessageRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            // User avatar
            Circle()
                .fill(Color.loopedPrimary)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                )

            // Message content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.userName)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    Text(formatTimestamp(conversation.lastMessageTimestamp))
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Text(conversation.lastMessage)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now.addingTimeInterval(-86400), toGranularity: .day) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: date, to: now)
            if let days = components.day, days < 7 {
                return "\(days)d"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d"
                return formatter.string(from: date)
            }
        }
    }
}

#Preview {
    VStack {
        DrawerMessageRow(conversation: MockConversations.conversations[0])
        DrawerMessageRow(conversation: MockConversations.conversations[1])
        DrawerMessageRow(conversation: MockConversations.conversations[2])
    }
    .background(Color.loopedBackground)
}
