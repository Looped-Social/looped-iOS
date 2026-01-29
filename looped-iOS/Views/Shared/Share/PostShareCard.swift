import SwiftUI

struct PostShareCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("Looped")
                    .font(.loopedLogo)
                    .foregroundColor(.loopedPrimary)

                Spacer(minLength: 0)

                Text(post.communityName ?? post.communityShortName ?? "")
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Text(post.resolvedAuthorName)
                .font(.loopedHeadlineScaled)
                .foregroundColor(.loopedTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(post.content)
                .font(.loopedBodyScaled)
                .foregroundColor(.loopedTextPrimary)
                .lineLimit(10)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Text("Shared from Looped")
                .font(.loopedCaptionScaled)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(22)
        .frame(width: 360, height: 360, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.loopedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.loopedMutedBackground, lineWidth: 1)
        )
        .environment(\.colorScheme, .light)
    }
}

