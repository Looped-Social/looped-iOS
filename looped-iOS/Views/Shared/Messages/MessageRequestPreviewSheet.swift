import SwiftUI

struct MessageRequestPreviewSheet: View {
    let request: MessageRequest
    @ObservedObject var viewModel: MessagesViewModel
    let onApproved: (Conversation?) -> Void
    let onRejected: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var isProcessing: Bool {
        viewModel.processingRequestIds.contains(request.backendId)
    }

    private var previewMessage: Message {
        let trimmed = request.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        let content: String
        if !trimmed.isEmpty {
            content = trimmed
        } else if request.previewAttachments.isEmpty {
            content = "Sent a message"
        } else {
            // Match ChatViewModel behavior for attachment-only messages.
            content = "\u{200B}"
        }

        let resolvedSenderBackendId = request.senderBackendId ?? 0

        return Message(
            id: UUID.fromBackendId(request.backendId),
            backendId: request.backendId,
            content: content,
            senderId: UUID.fromBackendId(resolvedSenderBackendId),
            senderDisplayName: request.displayName,
            receiverId: nil,
            conversationBackendId: request.conversationBackendId,
            channelBackendId: request.channelBackendId,
            messageType: .direct,
            isRead: true,
            attachments: request.previewAttachments,
            createdAt: request.previewCreatedAt
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    HStack(alignment: .bottom, spacing: 8) {
                        ReceivedMessageBubble(message: previewMessage, showSenderName: false)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle("Message request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LoopedCancelTextButton(action: { dismiss() }, title: "Close")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
                .background(
                    Color.loopedBackground
                        .opacity(0.98)
                        .ignoresSafeArea()
                )
        }
    }

    private var timestampText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: request.previewCreatedAt)
    }

    @ViewBuilder
    private var headerSection: some View {
        Group {
            if let backendId = request.senderBackendId {
                NavigationLink(destination: UserProfileView(userId: backendId)) {
                    headerContent
                }
                .buttonStyle(.plain)
            } else {
                headerContent
            }
        }
    }

    private var headerContent: some View {
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

            VStack(alignment: .leading, spacing: 2) {
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

                Text(timestampText)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.loopedMutedBackground)
        )
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            MessageRequestActionButton(
                title: "Reject",
                style: .secondary,
                isLoading: isProcessing,
                action: rejectTapped
            )

            MessageRequestActionButton(
                title: "Approve",
                style: .primary,
                isLoading: isProcessing,
                action: approveTapped
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func approveTapped() {
        Task { @MainActor in
            let conversation = await viewModel.approveMessageRequest(request)
            let didRemoveRequest = !viewModel.messageRequests.contains(where: { $0.backendId == request.backendId })
            guard didRemoveRequest else { return }
            dismiss()
            onApproved(conversation)
        }
    }

    private func rejectTapped() {
        Task { @MainActor in
            await viewModel.rejectMessageRequest(request)
            let didRemoveRequest = !viewModel.messageRequests.contains(where: { $0.backendId == request.backendId })
            guard didRemoveRequest else { return }
            dismiss()
            onRejected()
        }
    }
}

private struct MessageRequestActionButton: View {
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
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview {
    MessageRequestPreviewSheet(
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
        viewModel: MessagesViewModel(),
        onApproved: { _ in },
        onRejected: {}
    )
}
