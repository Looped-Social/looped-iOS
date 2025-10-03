import SwiftUI

struct CommentRow: View {
    let comment: Comment
    let nestingLevel: Int
    @State private var isLiked = false
    @State private var showReplies = false
    @State private var visibleRepliesCount = 5

    private let repliesPerPage = 5

    init(comment: Comment, nestingLevel: Int = 0) {
        self.comment = comment
        self.nestingLevel = nestingLevel
    }
    
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
    
    private var allReplies: [Comment] {
        MockComments.getRepliesForComment(comment.id)
    }

    private var totalRepliesCount: Int {
        allReplies.count
    }

    private var displayedReplies: [Comment] {
        Array(allReplies.prefix(visibleRepliesCount))
    }

    private var hasMoreReplies: Bool {
        totalRepliesCount > visibleRepliesCount
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

                    // View/Hide replies buttons
                    if totalRepliesCount > 0 {
                        HStack(spacing: 12) {
                            // View replies button
                            Button(action: {
                                withAnimation {
                                    showReplies.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("-- View \(totalRepliesCount) \(totalRepliesCount == 1 ? "reply" : "replies")")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)

                                    Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.loopedTextSecondary)
                                }
                            }

                            // Hide button (only show when replies are visible)
                            if showReplies {
                                Button(action: {
                                    withAnimation {
                                        showReplies = false
                                        visibleRepliesCount = repliesPerPage
                                    }
                                }) {
                                    Text("Hide")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }

                    // Replies section (when expanded)
                    if showReplies {
                        VStack(spacing: 0) {
                            ForEach(displayedReplies) { reply in
                                CommentRow(comment: reply, nestingLevel: nestingLevel + 1)

                                // Divider between replies
                                if reply.id != displayedReplies.last?.id || hasMoreReplies {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.loopedTextSecondary.opacity(0.05))
                                        .padding(.leading, nestingLevel > 0 ? 44 : 48)
                                }
                            }

                            // Show more and Hide buttons
                            if hasMoreReplies {
                                HStack(spacing: 12) {
                                    Button(action: {
                                        withAnimation {
                                            visibleRepliesCount += repliesPerPage
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Text("-- Show more replies (\(totalRepliesCount - visibleRepliesCount) remaining)")
                                                .font(.loopedSmallText)
                                                .foregroundColor(.loopedTextSecondary)

                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.loopedTextSecondary)
                                        }
                                    }

                                    Button(action: {
                                        withAnimation {
                                            showReplies = false
                                            visibleRepliesCount = repliesPerPage
                                        }
                                    }) {
                                        Text("Hide")
                                            .font(.loopedSmallText)
                                            .foregroundColor(.loopedTextSecondary)
                                    }
                                }
                                .padding(.leading, nestingLevel > 0 ? 44 : 48)
                                .padding(.vertical, 12)
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