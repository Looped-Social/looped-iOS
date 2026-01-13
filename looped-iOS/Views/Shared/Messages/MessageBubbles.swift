import SwiftUI
import UIKit

private enum MessageBubbleTimeFormatters {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

private enum MessageBubbleLayout {
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
    static let bubbleMaxWidth: CGFloat = min(420, UIScreen.main.bounds.width * 0.72)
}

private struct ChatBubbleWidthLayout: Layout {
    let maxWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }

        let unconstrained = subview.sizeThatFits(ProposedViewSize(width: nil, height: proposal.height))
        if unconstrained.width <= maxWidth {
            let resolved = subview.sizeThatFits(ProposedViewSize(width: unconstrained.width, height: proposal.height))
            return CGSize(width: unconstrained.width, height: resolved.height)
        }

        let constrained = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: proposal.height))
        return CGSize(width: min(maxWidth, constrained.width), height: constrained.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        subview.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

// MARK: - Sent Message Bubble (User's Messages)
struct SentMessageBubble: View {
    let message: Message
    let isGroupStart: Bool
    let isGroupEnd: Bool

    @State private var selectedImageUrl: String?
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideoUrl: String?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false

    init(message: Message, isGroupStart: Bool = true, isGroupEnd: Bool = true) {
        self.message = message
        self.isGroupStart = isGroupStart
        self.isGroupEnd = isGroupEnd
    }

    private var imageUrls: [String] {
        message.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Show media if present
            if let attachments = message.attachments, !attachments.isEmpty {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    if attachment.type == .video {
                        // Video thumbnail with play button
                        ZStack {
                            AsyncImage(url: URL(string: attachment.thumbnailUrl ?? attachment.url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.loopedMutedBackground)
                                    .overlay(ProgressView())
                            }
                            .frame(maxWidth: 220, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Play button overlay
                            Circle()
                                .fill(Color.loopedBlack.opacity(0.6))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.loopedCustom(size: 22))
                                        .foregroundColor(.loopedWhite)
                                        .offset(x: 2)
                                )
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if message.content.isEmpty, index == attachments.count - 1 {
                                MessageMediaTimeBadge(timeText: formatBubbleTime(message.createdAt))
                            }
                        }
                        .onTapGesture {
                            selectedVideoUrl = attachment.url
                            showVideoPlayer = true
                        }
                    } else {
                        AsyncImage(url: URL(string: attachment.url)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.loopedMutedBackground)
                                .overlay(ProgressView())
                        }
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .bottomTrailing) {
                            if message.content.isEmpty, index == attachments.count - 1 {
                                MessageMediaTimeBadge(timeText: formatBubbleTime(message.createdAt))
                            }
                        }
                        .onTapGesture {
                            // Find the index of the tapped image among all images
                            if let index = imageUrls.firstIndex(of: attachment.url) {
                                selectedImageIndex = index
                            }
                            selectedImageUrl = attachment.url
                            showImageViewer = true
                        }
                    }
                }
            }

            // Show text if present
            if !message.content.isEmpty {
                let bubbleShape = ChatBubbleShape(isFromCurrentUser: true, isGroupStart: isGroupStart, isGroupEnd: isGroupEnd)
                ChatBubbleWidthLayout(maxWidth: MessageBubbleLayout.bubbleMaxWidth) {
                    bubbleTextWithNewlineTime(message: message, isFromCurrentUser: true)
                        .padding(.horizontal, MessageBubbleLayout.horizontalPadding)
                        .padding(.vertical, MessageBubbleLayout.verticalPadding)
                }
                .background(Color.loopedMessageColor)
                .clipShape(bubbleShape)
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
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoUrl = selectedVideoUrl {
                VideoPlayerSheet(videoUrl: videoUrl, isPresented: $showVideoPlayer)
            }
        }
    }
}

// MARK: - Received Message Bubble (Other Users' Messages)
struct ReceivedMessageBubble: View {
    let message: Message
    let showSenderName: Bool
    let isGroupStart: Bool
    let isGroupEnd: Bool

    @State private var selectedImageUrl: String?
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideoUrl: String?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false

    init(
        message: Message,
        showSenderName: Bool,
        isGroupStart: Bool = true,
        isGroupEnd: Bool = true
    ) {
        self.message = message
        self.showSenderName = showSenderName
        self.isGroupStart = isGroupStart
        self.isGroupEnd = isGroupEnd
    }

    private var imageUrls: [String] {
        message.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Sender Name (only for group chats)
            if showSenderName {
                Text(message.senderDisplayName ?? "Unknown User")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.leading, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Show media if present
                if let attachments = message.attachments, !attachments.isEmpty {
                    ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                        if attachment.type == .video {
                            // Video thumbnail with play button
                            ZStack {
                                AsyncImage(url: URL(string: attachment.thumbnailUrl ?? attachment.url)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.loopedMutedBackground)
                                        .overlay(ProgressView())
                                }
                                .frame(maxWidth: 220, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                // Play button overlay
                                Circle()
                                    .fill(Color.loopedBlack.opacity(0.6))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "play.fill")
                                            .font(.loopedCustom(size: 22))
                                            .foregroundColor(.loopedWhite)
                                            .offset(x: 2)
                                    )
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if message.content.isEmpty, index == attachments.count - 1 {
                                    MessageMediaTimeBadge(timeText: formatBubbleTime(message.createdAt))
                                }
                            }
                            .onTapGesture {
                                selectedVideoUrl = attachment.url
                                showVideoPlayer = true
                            }
                        } else {
                            AsyncImage(url: URL(string: attachment.url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.loopedMutedBackground)
                                    .overlay(ProgressView())
                            }
                            .frame(maxWidth: 220, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .bottomTrailing) {
                                if message.content.isEmpty, index == attachments.count - 1 {
                                    MessageMediaTimeBadge(timeText: formatBubbleTime(message.createdAt))
                                }
                            }
                            .onTapGesture {
                                // Find the index of the tapped image among all images
                                if let index = imageUrls.firstIndex(of: attachment.url) {
                                    selectedImageIndex = index
                                }
                                selectedImageUrl = attachment.url
                                showImageViewer = true
                            }
                        }
                    }
                }

                // Show text if present
                if !message.content.isEmpty {
                    let bubbleShape = ChatBubbleShape(isFromCurrentUser: false, isGroupStart: isGroupStart, isGroupEnd: isGroupEnd)
                    ChatBubbleWidthLayout(maxWidth: MessageBubbleLayout.bubbleMaxWidth) {
                        bubbleTextWithNewlineTime(message: message, isFromCurrentUser: false)
                            .padding(.horizontal, MessageBubbleLayout.horizontalPadding)
                            .padding(.vertical, MessageBubbleLayout.verticalPadding)
                    }
                    .background(Color.loopedMessageMutedColor)
                    .clipShape(bubbleShape)
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
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoUrl = selectedVideoUrl {
                VideoPlayerSheet(videoUrl: videoUrl, isPresented: $showVideoPlayer)
            }
        }
    }
}

// MARK: - Image Message Bubble (for handling image attachments)
struct ImageMessageBubble: View {
    let message: Message
    let imageUrl: String
    let showProfilePicture: Bool
    let showSenderName: Bool
    let isFromCurrentUser: Bool

    @State private var showImageViewer = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isFromCurrentUser {
                // Profile Picture (only for group chats and received messages)
                if showProfilePicture {
                    ProfileAvatarView(imageURL: nil, size: 32)
                }
            }

            if isFromCurrentUser {
                Spacer()
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender Name (only for group chats and received messages)
                if showSenderName && !isFromCurrentUser {
                    Text(message.senderDisplayName ?? "Unknown User")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.leading, 4)
                }

                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Image with text overlay if there's content
                    VStack(spacing: 8) {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.loopedGray.opacity(0.3))
                                .frame(width: 200, height: 200)
                                .overlay(
                                    Text("IMG_\(String(imageUrl.suffix(4)))")
                                        .font(.loopedBodyMedium)
                                        .foregroundColor(.loopedTextSecondary)
                                )
                        }
                        .onTapGesture {
                            showImageViewer = true
                        }

                        if !message.content.isEmpty {
                            Text(message.content)
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextPrimary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isFromCurrentUser ? Color.loopedWhite : Color.loopedMessageColor)
                            .shadow(color: .loopedBlack.opacity(0.1), radius: 2, x: 0, y: 1)
                    )

                    Text(formatBubbleTime(message.createdAt))
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.leading, isFromCurrentUser ? 0 : 4)
                        .padding(.trailing, isFromCurrentUser ? 4 : 0)
                }
            }

            if !isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.leading, isFromCurrentUser ? 80 : (showProfilePicture ? 0 : 40))
        .padding(.trailing, isFromCurrentUser ? 0 : 80)
        .fullScreenCover(isPresented: $showImageViewer) {
            FullScreenImageViewer(
                imageUrls: [imageUrl],
                initialIndex: 0,
                isPresented: $showImageViewer
            )
        }
    }
}

// MARK: - Helper Functions
private func formatBubbleTime(_ date: Date) -> String {
    MessageBubbleTimeFormatters.timeOnly.string(from: date)
}

private func bubbleTextWithNewlineTime(message: Message, isFromCurrentUser: Bool) -> some View {
    let timeText = Text(formatBubbleTime(message.createdAt))
        .font(.loopedSmallText)
        .foregroundColor(.loopedTextSecondary)

    return VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
        Text(message.content)
            .font(.loopedBody)
            .foregroundColor(.loopedTextPrimary)
            .multilineTextAlignment(isFromCurrentUser ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)

        timeText
            .opacity(0)
            .accessibilityHidden(true)
    }
    .overlay(alignment: .bottomTrailing) {
        timeText
    }
}

private struct MessageMediaTimeBadge: View {
    let timeText: String

    var body: some View {
        Text(timeText)
            .font(.loopedSmallTextMedium)
            .foregroundColor(.loopedWhite)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.loopedBlack.opacity(0.55))
            )
            .padding(8)
    }
}
