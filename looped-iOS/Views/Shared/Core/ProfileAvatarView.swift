import SwiftUI

struct ProfileAvatarView: View {
    let imageURL: String?
    let size: CGFloat
    var iconScale: CGFloat = 0.45
    @AppStorage("anonymousMode") private var isAnonymousMode = false
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
        Group {
            if isRemoteDefaultAvatar {
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
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var defaultAvatar: some View {
        if UIImage(named: "profile-pic") != nil {
            Image("profile-pic")
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color.loopedAccent(isAnonymousMode: isAnonymousMode))
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.loopedCustom(.semibold, size: iconSize))
                        .foregroundColor(.loopedWhite)
                )
        }
    }
}
