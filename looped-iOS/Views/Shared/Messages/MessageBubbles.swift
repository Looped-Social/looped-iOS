import SwiftUI

// MARK: - Sent Message Bubble (User's Messages)
struct SentMessageBubble: View {
    let message: Message
    let showTail: Bool

    @State private var selectedImageUrl: String?
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideoUrl: String?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false

    init(message: Message, showTail: Bool = true) {
        self.message = message
        self.showTail = showTail
    }

    private var imageUrls: [String] {
        message.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    var body: some View {
        HStack {
            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Show media if present
                if let attachments = message.attachments, !attachments.isEmpty {
                    ForEach(attachments) { attachment in
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
                    Text(message.content)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Color.loopedMessageColor
                        )
                        .clipShape(TailCornerShape(isFromCurrentUser: true, showTail: showTail))
                        .shadow(color: .loopedBlack.opacity(0.2), radius: 2, x: 0, y: 3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(formatMessageTime(message.createdAt))
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.leading, 60)
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
    let showProfilePicture: Bool
    let showSenderName: Bool
    let showTail: Bool
    let onProfileTap: ((UUID) -> Void)?

    @State private var selectedImageUrl: String?
    @State private var selectedImageIndex: Int = 0
    @State private var selectedVideoUrl: String?
    @State private var showImageViewer = false
    @State private var showVideoPlayer = false

    init(message: Message, showProfilePicture: Bool, showSenderName: Bool, showTail: Bool = true, onProfileTap: ((UUID) -> Void)? = nil) {
        self.message = message
        self.showProfilePicture = showProfilePicture
        self.showSenderName = showSenderName
        self.showTail = showTail
        self.onProfileTap = onProfileTap
    }

    private var imageUrls: [String] {
        message.attachments?.filter { $0.type == .image }.map { $0.url } ?? []
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Profile Picture (only for group chats)
            if showProfilePicture {
                Button(action: {
                    onProfileTap?(message.senderId)
                }) {
                    ProfileAvatarView(imageURL: nil, size: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }

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
                        ForEach(attachments) { attachment in
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
                        Text(message.content)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                Color.loopedMessageMutedColor
                            )
                            .clipShape(TailCornerShape(isFromCurrentUser: false, showTail: showTail))
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .loopedBlack.opacity(0.2), radius: 2, x: 0, y: 3)
                    }

                    Text(formatMessageTime(message.createdAt))
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.leading, 4)
                }
            }

            Spacer()
        }
        .padding(.trailing, 60)
        .padding(.leading, showProfilePicture ? 0 : 20)
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

                    Text(formatMessageTime(message.createdAt))
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
private func formatMessageTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    let calendar = Calendar.current

    if calendar.isDate(date, inSameDayAs: Date()) {
        formatter.dateFormat = "h:mm a"
    } else {
        formatter.dateFormat = "MMM d, h:mm a"
    }

    return formatter.string(from: date)
}
