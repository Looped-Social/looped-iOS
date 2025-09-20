import SwiftUI

struct CommentRow: View {
    let comment: Comment
    @State private var isLiked = false
    
    private var displayName: String {
        if comment.isAnonymous {
            return "Anonymous"
        }
        return comment.authorDisplayName ?? "User"
    }
    
    private var handle: String {
        if comment.isAnonymous {
            return ""
        }
        return "@\(comment.authorDisplayName?.lowercased().replacingOccurrences(of: " ", with: "_") ?? "user")"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile picture
            AsyncImage(url: URL(string: "https://via.placeholder.com/36")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.loopedTextSecondary.opacity(0.3))
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            
            // Comment content
            VStack(alignment: .leading, spacing: 6) {
                // Header with name and timestamp
                HStack(alignment: .center, spacing: 6) {
                    Text(displayName)
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                    
                    if !comment.isAnonymous {
                        Text(handle)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }
                    
                    Text("•")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                    
                    Text(comment.createdAt, style: .relative)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                    
                    Spacer()
                }
                
                // Comment text
                Text(comment.content)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // "Liked by creator" badge
                if comment.isLikedByCreator {
                    Text("Liked by creator")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.top, 2)
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    // Reply button
                    Button(action: {}) {
                        Text("Reply")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                    }
                    
                    Spacer()
                    
                    // Like button with count
                    Button(action: { 
                        isLiked.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundColor(isLiked ? .red : .loopedTextSecondary)
                            
                            if comment.likeCount > 0 || isLiked {
                                Text("\(comment.likeCount + (isLiked ? 1 : 0))")
                                    .font(.loopedSmallText)
                                    .foregroundColor(.loopedTextSecondary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            isLiked = comment.userLiked
        }
    }
}

#Preview {
    let sampleComment = Comment(
        postId: UUID(),
        content: "Thank you for these! This is exactly what I needed to improve my workflow.",
        authorId: UUID(),
        authorDisplayName: "Sarah Chen",
        company: "Looped",
        isAnonymous: false,
        likeCount: 78,
        userLiked: false,
        isLikedByCreator: true,
        createdAt: Date().addingTimeInterval(-3600)
    )
    
    VStack {
        CommentRow(comment: sampleComment)
        
        Divider()
            .padding(.horizontal, 16)
        
        CommentRow(comment: Comment(
            postId: UUID(),
            content: "damn i didnt even realize i alr did all this except for the cleaning one i just always think oh lemme clean",
            authorId: UUID(),
            authorDisplayName: "Mike Rodriguez",
            company: "Looped",
            likeCount: 46,
            isLikedByCreator: true,
            createdAt: Date().addingTimeInterval(-7200)
        ))
    }
    .background(Color.loopedBackground)
}