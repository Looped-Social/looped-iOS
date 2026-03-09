import SwiftUI

struct SpecializationIcon: View {
    let name: String
    let memberCount: Int
    let specializationType: CommunitySpecializationType?
    let icon: CommunityIcon?
    let iconImageUrl: String?

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.loopedMutedBackground.opacity(0.12))
                .frame(width: 50, height: 50)
                .overlay { glyphView }
                .overlay(
                    Circle()
                        .stroke(Color.loopedMutedBackground, lineWidth: 1)
                )

            VStack(spacing: 2) {
                Text(name)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .lineLimit(1)

                Text("\(memberCount) members")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: 80)
    }

    private var glyphView: some View {
        Group {
            if let resolvedIcon = preferredIcon {
                specializationGlyph(for: resolvedIcon)
            } else {
                Text(initials)
                    .font(.loopedCustom(.semibold, size: 24))
                    .foregroundColor(.loopedPrimary)
            }
        }
    }

    @ViewBuilder
    private func specializationGlyph(for icon: CommunityIcon) -> some View {
        switch icon.kind {
        case .emoji:
            Text(icon.value)
                .font(.loopedCustom(.semibold, size: 26))
                .foregroundColor(.loopedTextPrimary)
        case .sfSymbol:
            Image(systemName: icon.value)
                .font(.loopedCustom(.semibold, size: 22))
                .foregroundColor(.loopedTextPrimary)
        case .imageUrl:
            if let url = URL.loopedMediaURL(from: icon.value) {
                LoopedDownsampledAsyncImage(url: url, maxPixelSize: 256) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Text(initials)
                            .font(.loopedCustom(.semibold, size: 24))
                            .foregroundColor(.loopedPrimary)
                    case .empty:
                        ProgressView()
                            .tint(.loopedTextSecondary)
                    }
                }
                .frame(width: 46, height: 46)
                .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.loopedCustom(.semibold, size: 24))
                    .foregroundColor(.loopedPrimary)
            }
        case .unknown:
            Text(initials)
                .font(.loopedCustom(.semibold, size: 24))
                .foregroundColor(.loopedPrimary)
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
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
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
        SpecializationIcon(name: "Computer Science", memberCount: 1800, specializationType: .field, icon: CommunityIcon(kind: .emoji, value: "💻"), iconImageUrl: nil)
        SpecializationIcon(name: "Business", memberCount: 2500, specializationType: .field, icon: CommunityIcon(kind: .sfSymbol, value: "graduationcap.fill"), iconImageUrl: nil)
        SpecializationIcon(name: "Marketing", memberCount: 1200, specializationType: .field, icon: CommunityIcon(kind: .emoji, value: "📣"), iconImageUrl: nil)
        SpecializationIcon(name: "Design", memberCount: 760, specializationType: .field, icon: nil, iconImageUrl: nil)
    }
    .padding()
    .background(Color.loopedBackground)
}
