import SwiftUI

struct SimplifiedPostCard: View {
    let post: Post

    private var authorName: String {
        post.resolvedAuthorName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with user info only
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                Group {
                    if post.isAnonymous {
                        Circle()
                            .fill(Color.loopedTextSecondary.opacity(0.3))
                            .overlay(
                                Text(String(authorName.prefix(1)).uppercased())
                                    .font(.loopedCustom(.semibold, size: 16))
                                    .foregroundColor(.loopedPrimary)
                            )
                            .frame(width: 40, height: 40)
                    } else {
                        ProfileAvatarView(imageURL: post.authorProfileImageURL, size: 40)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Name only (no username, job title, or timestamp)
                    Text(authorName)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                    
                    // Post content
                    if post.content.contains("#") {
                        HashtagText(
                            text: post.content,
                            font: .loopedBody,
                            textColor: .loopedTextPrimary,
                            hashtagColor: .loopedPrimary,
                            onHashtagTap: { _ in }
                        )
                        .multilineTextAlignment(.leading)
                    } else {
                        Text(post.content)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                    }
                    
                }
            }
        }
        .padding(16)
        .background(Color.loopedBackground)
    }
}

#Preview {
    let samplePost = Post(
        id: UUID(),
        content: "Excited to share my latest project, a redesign of our user onboarding flow. Focused on simplicity and clarity, resulting in a 20% increase in user retention. Check it out and let me know your thoughts!",
        authorId: UUID(),
        authorDisplayName: "Sarah Chen",
        company: "Looped",
        isAnonymous: false,
        reactionCount: 188,
        userReaction: nil,
        attachments: nil,
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: Date().addingTimeInterval(-86400)
    )

    SimplifiedPostCard(post: samplePost)
        .padding()
        .background(Color.loopedBackground)
}
