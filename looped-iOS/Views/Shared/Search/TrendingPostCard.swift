import SwiftUI
import UIKit

struct TrendingPostCard: View {
    let imageName: String
    let title: String
    let subtitle: String

    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            // Image with loading placeholder (supports either asset name or remote URL string)
            trendingImageContainer

            // Content overlay at bottom
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
                    // Prevent descenders (e.g. “g”) from getting clipped in tight layouts.
                    .padding(.bottom, 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.loopedBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.loopedBlack.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var trendingImageContainer: some View {
        ZStack {
            Color.loopedMutedBackground
            trendingImage
        }
        .aspectRatio(1.6, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var trendingImage: some View {
        Group {
            if let url = URL(string: imageName), url.scheme != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        imagePlaceholder(shimmer: false)
                    case .empty:
                        imagePlaceholder(shimmer: true)
                    @unknown default:
                        imagePlaceholder(shimmer: true)
                    }
                }
            } else if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                imagePlaceholder(shimmer: false)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func imagePlaceholder(shimmer: Bool) -> some View {
        Rectangle()
            .fill(Color.loopedMutedBackground)
            .overlay(
                Image(systemName: "photo")
                    .font(.loopedCustom(size: 40))
                    .foregroundColor(.loopedTextSecondary.opacity(0.5))
            )
            .shimmering(shimmer)
    }
}

#Preview {
    HStack(spacing: 16) {
        TrendingPostCard(
            imageName: "placeholder",
            title: "Latest company updates and announcements",
            subtitle: "Trending in Tech"
        )

        TrendingPostCard(
            imageName: "placeholder",
            title: "Remote work productivity tips",
            subtitle: "Trending in Business"
        )
    }
    .padding()
    .background(Color.loopedBackground)
}
