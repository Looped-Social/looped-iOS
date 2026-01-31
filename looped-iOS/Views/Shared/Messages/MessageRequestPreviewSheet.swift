import SwiftUI

struct MessageRequestPreviewSheet: View {
    let request: MessageRequest

    @Environment(\.dismiss) private var dismiss

    @State private var showImageViewer = false
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideo: VideoSelection?

    private var imageUrls: [String] {
        request.previewAttachments
            .filter { $0.type != .video }
            .map { $0.url }
    }

    private var resolvedMessageText: String {
        let trimmed = request.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if !request.previewAttachments.isEmpty {
            return "Sent an attachment"
        }
        return "Sent a message"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    VStack(alignment: .leading, spacing: 12) {
                        Text(resolvedMessageText)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !request.previewAttachments.isEmpty {
                            PostedMediaGrid(
                                attachments: request.previewAttachments,
                                maxHeight: 260,
                                onImageTap: handleImageTap(_:),
                                onVideoTap: handleVideoTap(_:)
                            )
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.loopedMutedBackground)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LoopedCancelTextButton(action: { dismiss() }, title: "Close")
                }
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if !imageUrls.isEmpty {
                FullScreenImageViewer(
                    imageUrls: imageUrls,
                    initialIndex: selectedImageIndex,
                    isPresented: $showImageViewer
                )
            }
        }
        .fullScreenCover(item: $selectedVideo) { selection in
            VideoPlayerSheet(
                selection: selection,
                isPresented: Binding(
                    get: { selectedVideo != nil },
                    set: { if !$0 { selectedVideo = nil } }
                )
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
                Text(request.displayName)
                    .font(.loopedBodyStrong)
                    .foregroundColor(.loopedTextPrimary)

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

    private func handleImageTap(_ url: String) {
        guard !imageUrls.isEmpty else { return }
        if let index = imageUrls.firstIndex(of: url) {
            selectedImageIndex = index
        } else {
            selectedImageIndex = 0
        }
        DispatchQueue.main.async {
            showImageViewer = true
        }
    }

    private func handleVideoTap(_ selection: VideoSelection) {
        selectedVideo = VideoSelection(
            url: selection.url,
            thumbnailUrl: selection.thumbnailUrl,
            authorName: request.displayName,
            authorImageUrl: request.senderProfileImageUrl,
            communityName: nil,
            caption: resolvedMessageText,
            inlineId: selection.inlineId,
            inlineViewModel: selection.inlineViewModel,
            postActionConfig: nil
        )
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
        )
    )
}

