import SwiftUI
import UIKit

struct LoopCard: View {
    @Environment(\.colorScheme) private var colorScheme
    private let illustrationInset: CGFloat = 4

    let title: String
    let description: String
    let memberCount: Int
    let imageURL: String?
    let icon: CommunityIcon?
    let iconImageUrl: String?
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color.loopedWhite.opacity(colorScheme == .dark ? 0.22 : 0.78),
                    lineWidth: 0.85
                )
                .blendMode(.overlay)
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.12 : 0.06),
            radius: colorScheme == .dark ? 7 : 4,
            x: 0,
            y: colorScheme == .dark ? 4 : 2
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.05 : 0.025),
            radius: 2,
            x: 0,
            y: 1
        )
    }

    private enum PlaceholderGlyph {
        case emoji(String)
        case system(String)
        case text(String)
        case remoteImage(String)
    }

    private var placeholderGlyph: PlaceholderGlyph {
        if let resolvedIcon = preferredIcon {
            switch resolvedIcon.kind {
            case .emoji:
                return .emoji(resolvedIcon.value)
            case .sfSymbol:
                return .system(resolvedIcon.value)
            case .imageUrl:
                return .remoteImage(resolvedIcon.value)
            case .unknown:
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
            return .emoji("🏢")
        default:
            return .system("person.3")
        }
    }

    private var bannerImage: some View {
        let localImage: UIImage? = {
            guard let imageURL else { return nil }
            return UIImage(named: imageURL)
        }()

        let resolvedRemoteURL: URL? = {
            if localImage != nil { return nil }
            if let resolved = URL.loopedMediaURL(from: imageURL) {
                return resolved
            }
            if let icon, let resolvedIcon = icon.normalizedOrNil(), resolvedIcon.kind == .imageUrl {
                return URL.loopedMediaURL(from: resolvedIcon.value)
            }
            return nil
        }()

        return Group {
            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFit()
                    .padding(usesContrastBackdrop ? illustrationInset : 0)
            } else if let resolvedRemoteURL {
                LoopedDownsampledAsyncImage(url: resolvedRemoteURL, maxPixelSize: 512) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(usesContrastBackdrop ? illustrationInset : 0)
                    case .failure:
                        placeholderImage
                    case .empty:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(imageBackdropColor)
    }

    private var imageBackdropColor: Color {
        guard usesContrastBackdrop else {
            return .loopedBackground
        }
        return Color.loopedCommunityImageBackdrop(for: colorScheme)
    }

    private var usesContrastBackdrop: Bool {
        let resolvedKind = kind ?? .unknown
        return resolvedKind.usesContrastImageBackdrop || resolvedKind == .specialization
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
                case .remoteImage(let value):
                    if let url = URL.loopedMediaURL(from: value) {
                        LoopedDownsampledAsyncImage(url: url, maxPixelSize: 256) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                            case .failure, .empty:
                                Text(placeholderText(from: title))
                                    .font(.loopedCustom(.semibold, size: 22))
                                    .foregroundColor(.loopedPrimary)
                            }
                        }
                    } else {
                        Text(placeholderText(from: title))
                            .font(.loopedCustom(.semibold, size: 22))
                            .foregroundColor(.loopedPrimary)
                    }
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

    private var preferredIcon: CommunityIcon? {
        CommunityIcon.imageURL(iconImageUrl) ?? icon?.normalizedOrNil()
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
            iconImageUrl: nil,
            kind: .company,
            specializationType: nil
        )

        LoopCard(
            title: "Design",
            description: "UX/UI design inspiration",
            memberCount: 890,
            imageURL: "trending2",
            icon: nil,
            iconImageUrl: nil,
            kind: .company,
            specializationType: nil
        )

        LoopCard(
            title: "Marketing",
            description: "Growth and strategy insights",
            memberCount: 640,
            imageURL: "trending3",
            icon: nil,
            iconImageUrl: nil,
            kind: .company,
            specializationType: nil
        )
    }
    .padding()
    .background(Color.loopedBackground)
}
