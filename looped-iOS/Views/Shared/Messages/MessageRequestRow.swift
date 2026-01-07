import SwiftUI

struct MessageRequestRow: View {
    let request: MessageRequest
    let isProcessing: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if request.isGroup {
                    Circle()
                        .fill(Color.loopedSecondary)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(request.displayName.prefix(1)).uppercased())
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedWhite)
                        )
                } else {
                    ProfileAvatarView(imageURL: request.senderProfileImageUrl, size: 44)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(request.displayName)
                            .font(.loopedBodyStrong)
                            .foregroundColor(.loopedTextPrimary)

                        if request.isGroup {
                            Text("Group")
                                .font(.loopedSmallTextMedium)
                                .foregroundColor(.loopedPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.loopedPrimary.opacity(0.12))
                                )
                        }
                    }

                    Text(request.previewSummary)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Text(request.formattedTimestamp)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }

            HStack(spacing: 12) {
                RequestActionButton(
                    title: "Reject",
                    style: .secondary,
                    isLoading: isProcessing,
                    action: onReject
                )

                RequestActionButton(
                    title: "Approve",
                    style: .primary,
                    isLoading: isProcessing,
                    action: onApprove
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.loopedMutedBackground)
        )
    }
}

private struct RequestActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let style: Style
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style == .primary ? .loopedWhite : .loopedPrimary))
                        .scaleEffect(0.8)
                }

                Text(title)
                    .font(.loopedSubBodyBold)
                    .foregroundColor(style == .primary ? .loopedWhite : .loopedPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(style == .primary ? Color.loopedPrimary : Color.loopedClear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style == .primary ? Color.loopedClear : Color.loopedPrimary, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageRequestRow(
            request: MessageRequest(
                backendId: 1,
                senderBackendId: 22,
                senderName: "Jordan",
                senderHandle: "jordan",
                senderProfileImageUrl: nil,
                previewText: "Hey, quick question about the team update.",
                previewAttachments: [],
                previewCreatedAt: Date(),
                status: .pending,
                conversationBackendId: 11,
                channelBackendId: nil,
                isGroup: false
            ),
            isProcessing: false,
            onApprove: {},
            onReject: {}
        )
    }
    .padding()
    .background(Color.loopedBackground)
}
