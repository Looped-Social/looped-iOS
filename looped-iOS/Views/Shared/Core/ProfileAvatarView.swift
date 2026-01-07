import SwiftUI

struct ProfileAvatarView: View {
    let imageURL: String?
    let size: CGFloat
    var iconScale: CGFloat = 0.45

    private var iconSize: CGFloat {
        size * iconScale
    }

    var body: some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.loopedPrimary)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.loopedCustom(.semibold, size: iconSize))
                    .foregroundColor(.loopedWhite)
            )
    }
}
