import SwiftUI

struct SimplifiedPostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with user info only
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: "https://via.placeholder.com/40")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 8) {
                    // Name only (no username, job title, or timestamp)
                    Text(post.isAnonymous ? "Anonymous" : (post.authorDisplayName ?? "User"))
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                    
                    // Post content
                    Text(post.content)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    // Hashtags (if any)
                    if post.content.contains("#") {
                        Text("#uxdesign #productdesign")
                            .font(.loopedBody)
                            .foregroundColor(.loopedPrimary)
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
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: Date().addingTimeInterval(-86400)
    )
    
    SimplifiedPostCard(post: samplePost)
        .padding()
        .background(Color.loopedBackground)
}