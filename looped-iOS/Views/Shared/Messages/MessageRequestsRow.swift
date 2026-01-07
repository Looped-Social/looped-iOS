import SwiftUI

struct MessageRequestsRow: View {
    let count: Int
    let preview: MessageRequest?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.loopedPrimary.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "tray.full.fill")
                        .font(.loopedCustom(.semibold, size: 18))
                        .foregroundColor(.loopedPrimary)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Requests")
                        .font(.loopedBodyStrong)
                        .foregroundColor(.loopedTextPrimary)

                    if count > 0 {
                        Text("\(count)")
                            .font(.loopedSmallTextMedium)
                            .foregroundColor(.loopedWhite)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.loopedPrimary)
                            )
                    }
                }

                Text(previewText)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.loopedCustom(.semibold, size: 14))
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.loopedMutedBackground)
        )
    }

    private var previewText: String {
        guard let preview else {
            return "Approve or reject new people."
        }
        return "\(preview.displayName): \(preview.previewSummary)"
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageRequestsRow(count: 3, preview: MessageRequest(
            backendId: 1,
            senderBackendId: 22,
            senderName: "Jordan",
            senderHandle: "jordan",
            senderProfileImageUrl: nil,
            previewText: "Hey, quick question",
            previewAttachments: [],
            previewCreatedAt: Date(),
            status: .pending,
            conversationBackendId: 11,
            channelBackendId: nil,
            isGroup: false
        ))
        MessageRequestsRow(count: 0, preview: nil)
    }
    .padding()
    .background(Color.loopedBackground)
}
