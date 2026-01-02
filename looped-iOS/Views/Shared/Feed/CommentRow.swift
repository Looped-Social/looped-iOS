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
    let canManage: ((Comment) -> Bool)?
    let onEdit: ((Comment) -> Void)?
    let onDelete: ((Comment) -> Void)?
    let onHashtagTap: ((String) -> Void)?

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
        onLike: ((Comment) -> Void)? = nil,
        canManage: ((Comment) -> Bool)? = nil,
        onEdit: ((Comment) -> Void)? = nil,
        onDelete: ((Comment) -> Void)? = nil,
        onHashtagTap: ((String) -> Void)? = nil
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
        self.canManage = canManage
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onHashtagTap = onHashtagTap
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
        nestingLevel == 0 ? 36 : 30
    }

    private var contentFont: Font {
        nestingLevel == 0 ? .loopedBody : .loopedSubBodyRegular
    }

    private var authorFont: Font {
        nestingLevel == 0 ? .loopedSubBodyRegular : .loopedSmallText
    }

    private var metadataFont: Font {
        .loopedSmallText
    }

    private var initials: String {
        String(displayName.prefix(1)).uppercased()
    }

    private var avatarView: some View {
        Group {
            if comment.isAnonymous {
                Circle()
                    .fill(Color.loopedTextSecondary.opacity(0.15))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.loopedTextSecondary)
                    )
            } else if let urlString = comment.authorProfileImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.2))
                }
            } else {
                Circle()
                    .fill(Color.loopedTextSecondary.opacity(0.15))
                    .overlay(
                        Text(initials)
                            .font(.loopedSmallTextMedium)
                            .foregroundColor(.loopedTextPrimary)
                    )
            }
        }
        .frame(width: profileSize, height: profileSize)
        .clipShape(Circle())
    }

    private var collapsedRepliesLabel: String? {
        guard comment.replyCount > 0 else { return nil }
        if comment.replyCount == 1 {
            return "1 more reply"
        }
        return "\(comment.replyCount) more replies"
    }

    private var remainingRepliesLabel: String {
        let remaining = max(comment.replyCount - replies.count, 0)
        if remaining == 1 {
            return "1 more reply"
        }
        if remaining > 1 {
            return "\(remaining) more replies"
        }
        return "See more replies"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                avatarView

                VStack(alignment: .leading, spacing: 8) {
                    if comment.isDeleted {
                        Text("Comment deleted")
                            .font(contentFont)
                            .foregroundColor(.loopedTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HashtagText(
                            text: comment.content,
                            font: contentFont,
                            textColor: .loopedTextPrimary,
                            hashtagColor: .loopedPrimary
                        ) { hashtag in
                            onHashtagTap?(hashtag)
                        }
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(displayName)
                        .font(authorFont)
                        .foregroundColor(.loopedTextSecondary)

                    if comment.isDeleted {
                        Text(formattedTimestamp)
                            .font(metadataFont)
                            .foregroundColor(.loopedTextSecondary)
                    } else {
                        HStack(spacing: 14) {
                            Text(formattedTimestamp)
                                .font(metadataFont)
                                .foregroundColor(.loopedTextSecondary)

                            Button(action: {
                                onReply?(comment)
                            }) {
                                Text("Reply")
                                    .font(metadataFont)
                                    .foregroundColor(.loopedTextSecondary)
                            }

                            Spacer()

                            Button(action: {
                                onLike?(comment)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: comment.userLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 12))
                                        .foregroundColor(comment.userLiked ? .red : .loopedTextSecondary)

                                    if comment.likeCount > 0 {
                                        Text("\(comment.likeCount)")
                                            .font(metadataFont)
                                            .foregroundColor(.loopedTextSecondary)
                                    }
                                }
                            }
                        }
                    }

                    if comment.isLikedByCreator, !comment.isDeleted {
                        Text("Liked by creator")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    if onToggleReplies != nil, !isExpanded, let label = collapsedRepliesLabel {
                        Button(action: { onToggleReplies?(comment) }) {
                            HStack(spacing: 8) {
                                Text(label)
                                    .font(metadataFont)
                                    .foregroundColor(.loopedTextSecondary)
                                if isLoadingReplies {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .padding(.top, 4)
                    }

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 16) {
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
                                    onLike: onLike,
                                    canManage: canManage,
                                    onEdit: onEdit,
                                    onDelete: onDelete,
                                    onHashtagTap: onHashtagTap
                                )
                            }

                            if isLoadingMoreReplies {
                                ProgressView()
                                    .padding(.vertical, 8)
                            } else if hasMoreReplies {
                                Button(action: { onLoadMoreReplies?(comment) }) {
                                    Text(remainingRepliesLabel)
                                        .font(metadataFont)
                                        .foregroundColor(.loopedTextSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(Color.loopedMutedBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.leading, nestingLevel > 0 ? CGFloat(nestingLevel * 16) : 0)
            .padding(.vertical, 6)
        }
        .contextMenu {
            if let canManage, canManage(comment), !comment.isDeleted {
                if let onEdit {
                    Button("Edit") { onEdit(comment) }
                }
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete(comment)
                    } label: {
                        Text("Delete")
                    }
                }
            }
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
