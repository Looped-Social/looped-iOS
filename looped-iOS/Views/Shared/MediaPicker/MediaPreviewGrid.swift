import SwiftUI
import AVKit

// MARK: - Media Preview Grid (for selection before posting)
struct MediaPreviewGrid: View {
    let media: [LocalMediaItem]
    let onRemove: (LocalMediaItem) -> Void
    let maxHeight: CGFloat

    init(media: [LocalMediaItem], maxHeight: CGFloat = 350, onRemove: @escaping (LocalMediaItem) -> Void) {
        self.media = media
        self.maxHeight = maxHeight
        self.onRemove = onRemove
    }

    var body: some View {
        if media.count == 1 {
            // Single large preview
            SingleMediaPreview(item: media[0], maxHeight: maxHeight, onRemove: onRemove)
        } else if media.count == 2 {
            // Two side-by-side
            HStack(spacing: 8) {
                ForEach(media) { item in
                    MediaThumbnail(item: item, onRemove: onRemove)
                }
            }
            .frame(maxHeight: maxHeight * 0.7)
        } else if media.count >= 3 {
            // Grid layout
            MediaGridLayout(media: media, maxHeight: maxHeight, onRemove: onRemove)
        }
    }
}

// MARK: - Single Media Preview
struct SingleMediaPreview: View {
    let item: LocalMediaItem
    let maxHeight: CGFloat
    let onRemove: (LocalMediaItem) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if item.type == .video, let videoURL = item.videoURL {
                // Video thumbnail with play button
                ZStack {
                    if let thumbnail = item.image {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: maxHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Play button overlay
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )

                    // Duration label
                    if let duration = item.duration {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(formatDuration(duration))
                                    .font(.loopedSmallText)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(12)
                            }
                        }
                    }
                }
            } else if let image = item.image {
                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Remove button
            Button(action: { onRemove(item) }) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .padding(8)
        }
    }
}

// MARK: - Media Thumbnail (for grid)
struct MediaThumbnail: View {
    let item: LocalMediaItem
    let onRemove: (LocalMediaItem) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if item.type == .video, let thumbnail = item.image {
                // Video thumbnail
                ZStack {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    // Play icon
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                }
            } else if let image = item.image {
                // Image thumbnail
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }

            // Remove button
            Button(action: { onRemove(item) }) {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Grid Layout
struct MediaGridLayout: View {
    let media: [LocalMediaItem]
    let maxHeight: CGFloat
    let onRemove: (LocalMediaItem) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if media.count == 3 {
                // 2 on top, 1 on bottom
                HStack(spacing: 8) {
                    MediaThumbnail(item: media[0], onRemove: onRemove)
                    MediaThumbnail(item: media[1], onRemove: onRemove)
                }
                .frame(height: maxHeight * 0.4)

                MediaThumbnail(item: media[2], onRemove: onRemove)
                    .frame(height: maxHeight * 0.4)
            } else {
                // 2x2 grid for 4+ items
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        MediaThumbnail(item: media[0], onRemove: onRemove)
                        MediaThumbnail(item: media[1], onRemove: onRemove)
                    }
                    HStack(spacing: 8) {
                        MediaThumbnail(item: media[2], onRemove: onRemove)
                        if media.count > 3 {
                            MediaThumbnail(item: media[3], onRemove: onRemove)
                        }
                    }
                }
                .frame(maxHeight: maxHeight)
            }
        }
    }
}

// MARK: - Posted Media Display Grid
struct PostedMediaGrid: View {
    let attachments: [MediaAttachment]
    let maxHeight: CGFloat

    init(attachments: [MediaAttachment], maxHeight: CGFloat = 350) {
        self.attachments = attachments
        self.maxHeight = maxHeight
    }

    var body: some View {
        if attachments.count == 1 {
            // Single large display
            SinglePostedMedia(attachment: attachments[0], maxHeight: maxHeight)
        } else if attachments.count == 2 {
            // Two side-by-side
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    PostedMediaThumbnail(attachment: attachment)
                }
            }
            .frame(maxHeight: maxHeight * 0.7)
        } else if attachments.count >= 3 {
            // Grid layout
            PostedMediaGridLayout(attachments: attachments, maxHeight: maxHeight)
        }
    }
}

// MARK: - Single Posted Media
struct SinglePostedMedia: View {
    let attachment: MediaAttachment
    let maxHeight: CGFloat

    var body: some View {
        if attachment.type == .video {
            // Video player
            VideoPlayerView(url: attachment.url)
                .frame(maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            // Image
            AsyncImage(url: URL(string: attachment.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.loopedMutedBackground)
                    .overlay(
                        ProgressView()
                    )
            }
            .frame(maxHeight: maxHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Posted Media Thumbnail
struct PostedMediaThumbnail: View {
    let attachment: MediaAttachment

    var body: some View {
        ZStack {
            AsyncImage(url: URL(string: attachment.type == .video ? (attachment.thumbnailUrl ?? attachment.url) : attachment.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.loopedMutedBackground)
            }

            if attachment.type == .video {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Posted Media Grid Layout
struct PostedMediaGridLayout: View {
    let attachments: [MediaAttachment]
    let maxHeight: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            if attachments.count == 3 {
                HStack(spacing: 8) {
                    PostedMediaThumbnail(attachment: attachments[0])
                    PostedMediaThumbnail(attachment: attachments[1])
                }
                .frame(height: maxHeight * 0.4)

                PostedMediaThumbnail(attachment: attachments[2])
                    .frame(height: maxHeight * 0.4)
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        PostedMediaThumbnail(attachment: attachments[0])
                        PostedMediaThumbnail(attachment: attachments[1])
                    }
                    HStack(spacing: 8) {
                        PostedMediaThumbnail(attachment: attachments[2])
                        if attachments.count > 3 {
                            PostedMediaThumbnail(attachment: attachments[3])
                        }
                    }
                }
                .frame(maxHeight: maxHeight)
            }
        }
    }
}

// MARK: - Video Player View
struct VideoPlayerView: View {
    let url: String
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                Rectangle()
                    .fill(Color.loopedMutedBackground)
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            if let videoURL = URL(string: url) {
                player = AVPlayer(url: videoURL)
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

// MARK: - Helper Functions
private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

// MARK: - Previews
#Preview("Single Image") {
    VStack {
        MediaPreviewGrid(
            media: [
                LocalMediaItem(type: .image, image: UIImage(systemName: "photo"))
            ],
            onRemove: { _ in }
        )
    }
    .padding()
    .background(Color.loopedBackground)
}

#Preview("Multiple Images") {
    VStack {
        MediaPreviewGrid(
            media: [
                LocalMediaItem(type: .image, image: UIImage(systemName: "photo")),
                LocalMediaItem(type: .image, image: UIImage(systemName: "photo.fill")),
                LocalMediaItem(type: .image, image: UIImage(systemName: "photo.circle")),
                LocalMediaItem(type: .image, image: UIImage(systemName: "photo.circle.fill"))
            ],
            onRemove: { _ in }
        )
    }
    .padding()
    .background(Color.loopedBackground)
}
