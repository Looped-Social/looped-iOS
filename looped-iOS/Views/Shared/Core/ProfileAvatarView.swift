import SwiftUI

struct ProfileAvatarView: View {
    enum Variant: Equatable {
        case standard
        case anonymous
    }

    let imageURL: String?
    let size: CGFloat
    var iconScale: CGFloat = 0.45
    var variant: Variant = .standard
    @AppStorage("defaultProfileImageUrl") private var defaultProfileImageUrl = ""

    private var iconSize: CGFloat {
        size * iconScale
    }

    private var resolvedImageURL: String? {
        let trimmed = (imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }

        let fallback = defaultProfileImageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? nil : fallback
    }

    private var isRemoteDefaultAvatar: Bool {
        let trimmedRemote = (resolvedImageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRemote.isEmpty else { return true }

        let configuredDefault = defaultProfileImageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !configuredDefault.isEmpty else { return false }
        return trimmedRemote == configuredDefault
    }

    var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    private var avatarContent: some View {
        Group {
            if variant == .anonymous {
                defaultAvatar
            } else if isRemoteDefaultAvatar {
                defaultAvatar
            } else if let resolvedImageURL, let url = URL(string: resolvedImageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    defaultAvatar
                }
            } else {
                defaultAvatar
            }
        }
    }

    @ViewBuilder
    private var defaultAvatar: some View {
        if variant == .anonymous, UIImage(named: "profile-pic-anon") != nil {
            Image("profile-pic-anon")
                .resizable()
                .scaledToFill()
        } else if UIImage(named: "profile-pic") != nil {
            Image("profile-pic")
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(variant == .anonymous ? Color.loopedSecondary : Color.loopedPrimary)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.loopedCustom(.semibold, size: iconSize))
                        .foregroundColor(.loopedWhite)
                )
        }
    }
}
