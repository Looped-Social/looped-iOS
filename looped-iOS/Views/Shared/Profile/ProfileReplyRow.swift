import SwiftUI

struct ProfileReplyRow: View {
    let comment: Comment
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

                Text(comment.isDeleted ? "Comment deleted" : comment.content)
                    .font(.loopedBodyMedium)
                    .foregroundColor(comment.isDeleted ? .loopedTextSecondary : .loopedTextPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)

                Text(comment.createdAt, style: .date)
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
