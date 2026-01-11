import SwiftUI

struct UserContentReplyRow: View {
    let reply: UserContentReply
    let previewText: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                if let previewText {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("In reply to")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)

                        Text(previewText)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Text(reply.isDeleted ? "Comment deleted" : reply.content)
                    .font(.loopedBodyMedium)
                    .foregroundColor(reply.isDeleted ? .loopedTextSecondary : .loopedTextPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)

                Text(reply.createdAt, style: .date)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

