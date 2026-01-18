import SwiftUI
import UIKit

struct LoopCard: View {
    let title: String
    let description: String
    let memberCount: Int
    let imageURL: String?

    var body: some View {
        VStack(spacing: 8) {
            bannerImage
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 4) {
                Text(title)
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1)

                Text(description)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("\(memberCount) members")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(Color.loopedBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.loopedMutedBackground, lineWidth: 1)
        )
    }

    private var bannerImage: some View {
        Group {
            if let imageURL, let url = URL(string: imageURL), url.scheme != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        placeholderImage
                    case .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else if let imageURL, let localImage = UIImage(named: imageURL) {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholderImage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground)
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.loopedBackground)
            .overlay(
                Image(systemName: "person.3")
                    .font(.loopedCustom(size: 20))
                    .foregroundColor(.loopedTextSecondary.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.loopedMutedBackground, lineWidth: 1)
            )
    }
}

#Preview {
    HStack(spacing: 16) {
        LoopCard(
            title: "Engineering",
            description: "Tech discussions and career tips",
            memberCount: 1250,
            imageURL: "trending1"
        )

        LoopCard(
            title: "Design",
            description: "UX/UI design inspiration",
            memberCount: 890,
            imageURL: "trending2"
        )

        LoopCard(
            title: "Marketing",
            description: "Growth and strategy insights",
            memberCount: 640,
            imageURL: "trending3"
        )
    }
    .padding()
    .background(Color.loopedBackground)
}
