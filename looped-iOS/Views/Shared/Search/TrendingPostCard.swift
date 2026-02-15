import SwiftUI
import UIKit

struct TrendingPostCard: View {
    let imageName: String
    let title: String
    let contentPreview: String
    let authorName: String
    let authorImageURL: String?
    let isAnonymousAuthor: Bool
    let postedInText: String
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 12
    private let imageHeight: CGFloat = 152

    var body: some View {
        VStack(spacing: 0) {
            // Image with loading placeholder (supports either asset name or remote URL string)
            trendingImageContainer

            // Content overlay at bottom
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 10) {
                    ProfileAvatarView(
                        imageURL: authorImageURL,
                        size: 32,
                        iconScale: 0.4,
                        variant: isAnonymousAuthor ? .anonymous : .standard
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(authorName)
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)
                            .lineLimit(1)

                        Text(postedInText)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                            .lineLimit(1)
                            .padding(.top, -2)
                    }

                    Spacer(minLength: 0)
                }

                if !contentPreview.isEmpty {
                    Text(contentPreview)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if contentPreview != title {
                    Text(title)
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.loopedBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    Color.loopedWhite.opacity(colorScheme == .dark ? 0.22 : 0.78),
                    lineWidth: 0.85
                )
                .blendMode(.overlay)
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.2 : 0.11),
            radius: colorScheme == .dark ? 12 : 7,
            x: 0,
            y: colorScheme == .dark ? 8 : 4
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.1 : 0.05),
            radius: colorScheme == .dark ? 3 : 2,
            x: 0,
            y: 1
        )
    }

    private var trendingImageContainer: some View {
        ZStack {
            Color.loopedMutedBackground
            trendingImage
        }
        .frame(height: imageHeight)
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
            contentPreview: "Thank you for a successful launch - we are looking forward to rolling out more.",
            authorName: "Looped",
            authorImageURL: nil,
            isAnonymousAuthor: false,
            postedInText: "Posted in Tech"
        )

        TrendingPostCard(
            imageName: "placeholder",
            title: "Remote work productivity tips",
            contentPreview: "Sharing three habits that helped our team move faster this quarter.",
            authorName: "Anonymous",
            authorImageURL: nil,
            isAnonymousAuthor: true,
            postedInText: "Posted in Business"
        )
    }
    .padding()
    .background(Color.loopedBackground)
}
