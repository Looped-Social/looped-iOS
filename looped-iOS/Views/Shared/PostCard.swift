import SwiftUI

struct PostCard: View {
    let post: Post
    @State private var isLiked = false
    @State private var isBookmarked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with user info
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
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        // Name and handle
                        Text(post.isAnonymous ? "Anonymous" : (post.authorDisplayName ?? "User"))
                            .font(.headline)
                            .foregroundColor(.loopedTextPrimary)
                        
                        if !post.isAnonymous {
                            Text("@\(post.authorDisplayName?.lowercased().replacingOccurrences(of: " ", with: "") ?? "user")")
                                .font(.subheadline)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        
                        Spacer()
                        
                        // More button
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }
                    
                    // Job title, company, and time
                    HStack(spacing: 4) {
                        Text("\(post.isAnonymous ? "Employee" : "Product Designer") @ \(post.company)")
                            .font(.subheadline)
                            .foregroundColor(.loopedTextSecondary)
                        
                        Text("•")
                            .font(.subheadline)
                            .foregroundColor(.loopedTextSecondary)
                        
                        Text(post.createdAt, style: .relative)
                            .font(.subheadline)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
            }
            
            // Post content
            Text(post.content)
                .font(.body)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            // Hashtags (if any)
            if post.content.contains("#") {
                HStack {
                    Text("#uxdesign #productdesign")
                        .font(.body)
                        .foregroundColor(.loopedPrimary)
                }
            }
            
            // Engagement buttons
            HStack(spacing: 24) {
                // Like button
                Button(action: { isLiked.toggle() }) {
                    HStack(spacing: 4) {
                        Image("heart-icon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundColor(isLiked ? .red : .loopedTextSecondary)
                        Text("\(post.reactionCount + (isLiked ? 1 : 0))")
                            .font(.caption)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                
                // Comment button
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image("comment-icon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 18, height: 18)
                            .foregroundColor(.loopedTextSecondary)
                        Text("999")
                            .font(.caption)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                
                // Share button
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image("send-icon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 19, height: 19)
                            .foregroundColor(.loopedTextSecondary)
                        Text("67")
                            .font(.caption)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                
                Spacer()
                
                // Bookmark button
                Button(action: { isBookmarked.toggle() }) {
                    HStack(spacing: 4) {
                        Image("save-icon")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 18, height: 18)
                            .foregroundColor(isBookmarked ? .loopedPrimary : .loopedTextSecondary)
                        Text("999")
                            .font(.caption)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.loopedBackground)
        .cornerRadius(0)
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
    
    PostCard(post: samplePost)
        .padding()
        .background(Color.loopedBackground)
}
