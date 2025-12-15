import SwiftUI

struct CommentRow: View {
    let comment: Comment
    let nestingLevel: Int
    let replies: [Comment]
    let isExpanded: Bool
    let isLoadingReplies: Bool
    let isLoadingMoreReplies: Bool
    let hasMoreReplies: Bool
    let onReply: ((Comment) -> Void)?
    let onToggleReplies: ((Comment) -> Void)?
    let onLoadMoreReplies: ((Comment) -> Void)?
    let onLike: ((Comment) -> Void)?

    init(
        comment: Comment,
        nestingLevel: Int = 0,
        replies: [Comment] = [],
        isExpanded: Bool = false,
        isLoadingReplies: Bool = false,
        isLoadingMoreReplies: Bool = false,
        hasMoreReplies: Bool = false,
        onReply: ((Comment) -> Void)? = nil,
        onToggleReplies: ((Comment) -> Void)? = nil,
        onLoadMoreReplies: ((Comment) -> Void)? = nil,
        onLike: ((Comment) -> Void)? = nil
    ) {
        self.comment = comment
        self.nestingLevel = nestingLevel
        self.replies = replies
        self.isExpanded = isExpanded
        self.isLoadingReplies = isLoadingReplies
        self.isLoadingMoreReplies = isLoadingMoreReplies
        self.hasMoreReplies = hasMoreReplies
        self.onReply = onReply
        self.onToggleReplies = onToggleReplies
        self.onLoadMoreReplies = onLoadMoreReplies
        self.onLike = onLike
    }
    
    private var displayName: String {
        if comment.isAnonymous {
            return "Anonymous"
        }
        return comment.authorDisplayName ?? "User"
    }

    private var formattedTimestamp: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(comment.createdAt)

        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60

        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
    
    private var profileSize: CGFloat {
        nestingLevel == 0 ? 36 : 32
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Profile picture (or empty space for anonymous)
                if comment.isAnonymous {
                    // No profile picture for anonymous users
                    Color.clear
                        .frame(width: profileSize, height: profileSize)
                } else {
                    AsyncImage(url: URL(string: "https://via.placeholder.com/\(Int(profileSize))")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.loopedTextSecondary.opacity(0.3))
                    }
                    .frame(width: profileSize, height: profileSize)
                    .clipShape(Circle())
                }

                // Comment content
                VStack(alignment: .leading, spacing: 6) {
                    // Header with just name
                    Text(displayName)
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Comment text
                    Text(comment.content)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // "Liked by creator" badge
                    if comment.isLikedByCreator {
                        Text("Liked by creator")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                            .padding(.top, 2)
                    }

                    // Timestamp and Reply button
                    HStack(spacing: 16) {
                        Text(formattedTimestamp)
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)

                        Button(action: {
                            onReply?(comment)
                        }) {
                            Text("Reply")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }

                        Spacer()

                        // Like button with count
                        Button(action: {
                            onLike?(comment)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: comment.userLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                    .foregroundColor(comment.userLiked ? .red : .loopedTextSecondary)

                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                    
                    // Replies toggle/loading
                    if onToggleReplies != nil {
                        HStack(spacing: 8) {
                            Button(action: { onToggleReplies?(comment) }) {
                                HStack(spacing: 4) {
                                    Text(isExpanded ? "Hide replies" : "View replies")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)
                                    if isLoadingReplies {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else {
                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.loopedTextSecondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 8)
                    }

                    // Replies list
                    if isExpanded {
                        VStack(spacing: 0) {
                            if replies.isEmpty && !isLoadingReplies {
                                Text("No replies yet")
                                    .font(.loopedSmallText)
                                    .foregroundColor(.loopedTextSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, nestingLevel > 0 ? 44 : 48)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(replies) { reply in
                                    CommentRow(
                                        comment: reply,
                                        nestingLevel: nestingLevel + 1,
                                        replies: [],
                                        isExpanded: false,
                                        isLoadingReplies: false,
                                        isLoadingMoreReplies: false,
                                        hasMoreReplies: false,
                                        onReply: onReply,
                                        onToggleReplies: nil,
                                        onLoadMoreReplies: nil,
                                        onLike: onLike
                                    )

                                    if reply.id != replies.last?.id {
                                        Rectangle()
                                            .frame(height: 1)
                                            .foregroundColor(.loopedTextSecondary.opacity(0.05))
                                            .padding(.leading, nestingLevel > 0 ? 44 : 48)
                                    }
                                }
                            }

                            if isLoadingMoreReplies {
                                ProgressView()
                                    .padding(.vertical, 8)
                            } else if hasMoreReplies {
                                Button(action: { onLoadMoreReplies?(comment) }) {
                                    HStack(spacing: 4) {
                                        Text("Show more replies")
                                            .font(.loopedSmallText)
                                            .foregroundColor(.loopedTextSecondary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.loopedTextSecondary)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, nestingLevel == 0 ? 16 : 0)
            .padding(.leading, nestingLevel > 0 ? CGFloat(nestingLevel * 12) : 0)
            .padding(.vertical, 12)
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
