import SwiftUI

struct CommentsView: View {
    let post: Post
    let comments: [Comment]
    let onDismiss: () -> Void
    @State private var commentText: String = ""
    @State private var keyboardHeight: CGFloat = 0
    
    private var sortedComments: [Comment] {
        comments.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // Header
                HStack {
                    Text("\(comments.count) comment\(comments.count == 1 ? "" : "s")")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Spacer()

                    Button(action: { onDismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.loopedBackground)
                
                // Divider
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
                
                // Comments list
                if sortedComments.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.loopedTextSecondary.opacity(0.3))
                        
                        Text("No comments yet")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                        
                        Text("Be the first to share your thoughts!")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(sortedComments) { comment in
                                CommentRow(comment: comment)
                                
                                // Divider between comments
                                if comment.id != sortedComments.last?.id {
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.loopedTextSecondary.opacity(0.05))
                                        .padding(.horizontal, 16)
                                }
                            }
                            
                            // Bottom padding to account for input area
                            Rectangle()
                                .frame(height: 80)
                                .foregroundColor(.clear)
                        }
                    }
                }
                
                Spacer()
                
                // Input area - TikTok style at bottom
                VStack(spacing: 0) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        // User avatar
                        AsyncImage(url: URL(string: "https://via.placeholder.com/32")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.loopedTextSecondary.opacity(0.3))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        // Text input
                        HStack {
                            TextField("Add comment...", text: $commentText, axis: .vertical)
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextPrimary)
                                .lineLimit(1...4)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        .background(Color.loopedMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        // Action buttons
                        HStack(spacing: 8) {
                            // @ mention button
                            Button(action: {}) {
                                Image(systemName: "at")
                                    .font(.system(size: 20))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                            
                            // Gift/emoji button
                            Button(action: {}) {
                                Image(systemName: "gift")
                                    .font(.system(size: 20))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                            
                            // Emoji button
                            Button(action: {}) {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 20))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, max(12, keyboardHeight > 0 ? 0 : 12))
                    .background(Color.loopedBackground)
                }
        }
        .background(Color.loopedBackground)
        .onAppear {
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

#Preview {
    let samplePost = Post(
        id: UUID(),
        content: "Excited to share my latest project, a redesign of our user onboarding flow.",
        authorId: UUID(),
        authorDisplayName: "Sarah Chen",
        company: "Looped",
        isAnonymous: false,
        reactionCount: 188,
        userReaction: nil,
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: Date().addingTimeInterval(-86400)
    )
    
    let sampleComments = [
        Comment(
            postId: samplePost.id,
            content: "Thank you for these! This is exactly what I needed to improve my workflow.",
            authorId: UUID(),
            authorDisplayName: "Mike Rodriguez",
            company: "Looped",
            likeCount: 78,
            isLikedByCreator: true,
            createdAt: Date().addingTimeInterval(-3600)
        ),
        Comment(
            postId: samplePost.id,
            content: "damn i didnt even realize i alr did all this except for the cleaning one i just always think oh lemme clean",
            authorId: UUID(),
            authorDisplayName: "Alex Kim",
            company: "Looped",
            likeCount: 46,
            isLikedByCreator: true,
            createdAt: Date().addingTimeInterval(-7200)
        ),
        Comment(
            postId: samplePost.id,
            content: "Absolutely amazing work! 🔥",
            authorId: UUID(),
            authorDisplayName: "Jennifer Liu",
            company: "Looped",
            likeCount: 32,
            isLikedByCreator: false,
            createdAt: Date().addingTimeInterval(-10800)
        ),
        Comment(
            postId: samplePost.id,
            content: "Thank you!",
            authorId: UUID(),
            authorDisplayName: "David Park",
            company: "Looped",
            likeCount: 19,
            isLikedByCreator: true,
            createdAt: Date().addingTimeInterval(-14400)
        )
    ]
    
    CommentsView(post: samplePost, comments: sampleComments, onDismiss: {})
}
