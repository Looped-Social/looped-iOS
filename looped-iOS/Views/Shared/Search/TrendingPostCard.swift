import SwiftUI

struct TrendingPostCard: View {
    let imageName: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 0) {
            // Image placeholder with aspect ratio matching design
            Rectangle()
                .fill(Color.loopedMutedBackground)
                .aspectRatio(1.6, contentMode: .fit)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.loopedTextSecondary.opacity(0.5))
                )

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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.loopedBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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