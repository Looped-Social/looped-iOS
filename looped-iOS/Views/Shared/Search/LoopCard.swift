import SwiftUI
import UIKit

struct LoopCard: View {
    let title: String
    let description: String
    let memberCount: Int
    let imageURL: String?
    let kind: CommunityKind?
    let specializationType: CommunitySpecializationType?

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

    private enum PlaceholderGlyph {
        case emoji(String)
        case system(String)
    }

    private var placeholderGlyph: PlaceholderGlyph {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedWithoutPunctuation = normalizedTitle
            .replacingOccurrences(of: "&", with: " and ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")

        if kind == .specialization {
            if normalizedWithoutPunctuation.contains("computer science")
                || normalizedWithoutPunctuation.contains(" cs ")
                || normalizedWithoutPunctuation.hasPrefix("cs ")
                || normalizedWithoutPunctuation.hasSuffix(" cs") {
                return .emoji("💻")
            }
            if normalizedWithoutPunctuation.contains("investment")
                || normalizedWithoutPunctuation.contains("banking")
                || normalizedWithoutPunctuation.contains("ib ") {
                return .emoji("📈")
            }
            if normalizedWithoutPunctuation.contains("finance") {
                return .emoji("💰")
            }
            if specializationType == .department {
                return .emoji("🏷️")
            }
            return .emoji("🎓")
        }

        switch kind {
        case .company:
            return .emoji("🏢")
        case .school:
            return .emoji("🎓")
        case .profession:
            return .emoji("💼")
        case .sector:
            return .emoji("🏭")
        default:
            return .system("person.3")
        }
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
            .fill(Color.loopedMutedBackground.opacity(0.12))
            .overlay {
                switch placeholderGlyph {
                case .emoji(let emoji):
                    Text(emoji)
                        .font(.loopedCustom(.semibold, size: 26))
                        .foregroundColor(.loopedTextPrimary)
                case .system(let symbol):
                    Image(systemName: symbol)
                        .font(.loopedCustom(size: 20))
                        .foregroundColor(.loopedTextSecondary.opacity(0.6))
                }
            }
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
            imageURL: "trending1",
            kind: .profession,
            specializationType: nil
        )

        LoopCard(
            title: "Design",
            description: "UX/UI design inspiration",
            memberCount: 890,
            imageURL: "trending2",
            kind: .profession,
            specializationType: nil
        )

        LoopCard(
            title: "Marketing",
            description: "Growth and strategy insights",
            memberCount: 640,
            imageURL: "trending3",
            kind: .profession,
            specializationType: nil
        )
    }
    .padding()
    .background(Color.loopedBackground)
}
