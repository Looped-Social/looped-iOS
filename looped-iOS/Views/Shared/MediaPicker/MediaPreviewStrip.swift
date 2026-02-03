import SwiftUI

struct MediaPreviewStrip: View {
    let media: [LocalMediaItem]
    let onRemove: (LocalMediaItem) -> Void

    init(media: [LocalMediaItem], onRemove: @escaping (LocalMediaItem) -> Void) {
        self.media = media
        self.onRemove = onRemove
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(media) { item in
                    MediaPreviewStripItem(item: item, onRemove: onRemove)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .frame(height: 92)
    }
}

private struct MediaPreviewStripItem: View {
    let item: LocalMediaItem
    let onRemove: (LocalMediaItem) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                if let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.loopedMutedBackground
                        .overlay(
                            Image(systemName: "photo")
                                .font(.loopedCustom(size: 18))
                                .foregroundColor(.loopedTextSecondary)
                        )
                }

                if item.type == .video {
                    Circle()
                        .fill(Color.loopedBlack.opacity(0.6))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.loopedCustom(size: 11))
                                .foregroundColor(.loopedWhite)
                        )
                }
            }
            .frame(width: 80, height: 80)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button(action: { onRemove(item) }) {
                Circle()
                    .fill(Color.loopedBlack.opacity(0.7))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.loopedCustom(.bold, size: 10))
                            .foregroundColor(.loopedWhite)
                    )
            }
            .padding(6)
            .loopedTapTarget()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.type == .video ? "Selected video" : "Selected photo")
    }
}
