import SwiftUI
import UIKit

struct LoopCard: View {
    let title: String
    let description: String
    let memberCount: Int
    let imageURL: String?
    let icon: CommunityIcon?
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
        case text(String)
    }

    private var placeholderGlyph: PlaceholderGlyph {
        if let resolvedIcon = icon?.normalizedOrNil() {
            switch resolvedIcon.kind {
            case .emoji:
                return .emoji(resolvedIcon.value)
            case .sfSymbol:
                return .system(resolvedIcon.value)
            case .imageUrl, .unknown:
                break
            }
        }

        if kind == .specialization {
            return .text(placeholderText(from: title))
        }

        switch kind {
        case .company:
            return .emoji("🏢")
        case .school:
            return .emoji("🎓")
        default:
            return .system("person.3")
        }
    }

    private var bannerImage: some View {
        let resolvedImageURL: String? = {
            if let imageURL, let url = URL(string: imageURL), url.scheme != nil { return imageURL }
            if let icon, let resolved = icon.normalizedOrNil(), resolved.kind == .imageUrl { return resolved.value }
            return imageURL
        }()

        return Group {
            if let resolvedImageURL, let url = URL(string: resolvedImageURL), url.scheme != nil {
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
                case .text(let text):
                    Text(text)
                        .font(.loopedCustom(.semibold, size: 22))
                        .foregroundColor(.loopedPrimary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.loopedMutedBackground, lineWidth: 1)
            )
    }

    private func placeholderText(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }

        if trimmed.count <= 3, trimmed.contains(" ") == false {
            return trimmed.uppercased()
        }

        let parts = trimmed.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        let combined = (first + second).uppercased()
        return combined.isEmpty ? "?" : combined
    }
}

#Preview {
    HStack(spacing: 16) {
        LoopCard(
            title: "Engineering",
            description: "Tech discussions and career tips",
            memberCount: 1250,
            imageURL: "trending1",
            icon: nil,
            kind: .company,
            specializationType: nil
        )

        LoopCard(
            title: "Design",
            description: "UX/UI design inspiration",
            memberCount: 890,
            imageURL: "trending2",
            icon: nil,
            kind: .company,
            specializationType: nil
        )

        LoopCard(
            title: "Marketing",
            description: "Growth and strategy insights",
            memberCount: 640,
            imageURL: "trending3",
            icon: nil,
            kind: .company,
            specializationType: nil
        )
    }
    .padding()
    .background(Color.loopedBackground)
}
