#if DEBUG
import Foundation

struct MockComments {
    
    // MARK: - Sample Comments for Posts
    static func getCommentsForPost(_ postId: UUID) -> [Comment] {
        // Generate different comment sets based on post ID to simulate variety
        let postIdString = postId.uuidString
        let commentSeed = abs(postIdString.hashValue) % 5
        
        switch commentSeed {
        case 0:
            return designFeedbackComments(for: postId)
        case 1:
            return casualConversationComments(for: postId)
        case 2:
            return workDiscussionComments(for: postId)
        case 3:
            return celebratoryComments(for: postId)
        default:
            return mixedComments(for: postId)
        }
    }
    
    // MARK: - Design Feedback Comments
    private static func designFeedbackComments(for postId: UUID) -> [Comment] {
        return [
            Comment(
                postId: postId,
                content: "This is absolutely incredible! The attention to detail in the micro-interactions really makes it shine. How long did this take to implement?",
                authorId: MockUsers.colleagues[0].id,
                authorDisplayName: MockUsers.colleagues[0].displayName,
                company: MockUsers.colleagues[0].company,
                likeCount: 47,
                isLikedByCreator: true,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            Comment(
                postId: postId,
                content: "Love the clean aesthetic! The color palette works so well with the brand. Did you consider any accessibility considerations for color contrast?",
                authorId: MockUsers.colleagues[1].id,
                authorDisplayName: MockUsers.colleagues[1].displayName,
                company: MockUsers.colleagues[1].company,
                likeCount: 23,
                isLikedByCreator: true,
                createdAt: Date().addingTimeInterval(-7200)
            ),
            Comment(
                postId: postId,
                content: "Amazing work! 🔥 The user flow feels so intuitive now.",
                authorId: MockUsers.colleagues[2].id,
                authorDisplayName: MockUsers.colleagues[2].displayName,
                company: MockUsers.colleagues[2].company,
                likeCount: 12,
                createdAt: Date().addingTimeInterval(-10800)
            ),
            Comment(
                postId: postId,
                content: "Just showed this to my team and everyone is blown away. Mind sharing your design process?",
                authorId: MockUsers.colleagues[3].id,
                authorDisplayName: MockUsers.colleagues[3].displayName,
                company: MockUsers.colleagues[3].company,
                likeCount: 8,
                isLikedByCreator: false,
                createdAt: Date().addingTimeInterval(-14400)
            )
        ]
    }
    
    // MARK: - Casual Conversation Comments
    private static func casualConversationComments(for postId: UUID) -> [Comment] {
        return [
            Comment(
                postId: postId,
                content: "lol same here! I thought I was the only one dealing with this 😅",
                authorId: MockUsers.colleagues[1].id,
                authorDisplayName: MockUsers.colleagues[1].displayName,
                company: MockUsers.colleagues[1].company,
                likeCount: 156,
                createdAt: Date().addingTimeInterval(-1800)
            ),
            Comment(
                postId: postId,
                content: "fr tho, why is it always broken when you need it most? Murphy's law in action",
                authorId: MockUsers.colleagues[5].id,
                authorDisplayName: nil,
                company: MockUsers.colleagues[5].company,
                isAnonymous: true,
                likeCount: 89,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            Comment(
                postId: postId,
                content: "Have you tried turning it off and on again? 😂 (sorry, had to)",
                authorId: MockUsers.colleagues[2].id,
                authorDisplayName: MockUsers.colleagues[2].displayName,
                company: MockUsers.colleagues[2].company,
                likeCount: 34,
                isLikedByCreator: true,
                createdAt: Date().addingTimeInterval(-5400)
            ),
            Comment(
                postId: postId,
                content: "Facilities said they're working on it... that was 3 weeks ago 🤷‍♀️",
                authorId: MockUsers.colleagues[3].id,
                authorDisplayName: MockUsers.colleagues[3].displayName,
                company: MockUsers.colleagues[3].company,
                likeCount: 67,
                createdAt: Date().addingTimeInterval(-7200)
            )
        ]
    }
    
    // MARK: - Work Discussion Comments
    private static func workDiscussionComments(for postId: UUID) -> [Comment] {
        return [
            Comment(
                postId: postId,
                content: "100% agree with this take. We've been saying this for months but nobody wanted to listen",
                authorId: MockUsers.colleagues[5].id,
                authorDisplayName: nil,
                company: MockUsers.colleagues[5].company,
                isAnonymous: true,
                likeCount: 234,
                isLikedByCreator: true,
                createdAt: Date().addingTimeInterval(-900)
            ),
            Comment(
                postId: postId,
                content: "Maybe we should try planning smaller chunks? I've seen other teams have success with 1-week sprints",
                authorId: MockUsers.colleagues[0].id,
                authorDisplayName: MockUsers.colleagues[0].displayName,
                company: MockUsers.colleagues[0].company,
                likeCount: 78,
                createdAt: Date().addingTimeInterval(-2700)
            ),
            Comment(
                postId: postId,
                content: "The problem is we keep adding \"just one more thing\" to every sprint. Scope creep is real",
                authorId: MockUsers.colleagues[1].id,
                authorDisplayName: MockUsers.colleagues[1].displayName,
                company: MockUsers.colleagues[1].company,
                likeCount: 123,
                isLikedByCreator: false,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            Comment(
                postId: postId,
                content: "this is why I love working here - people actually speak up about process issues instead of just complaining privately",
                authorId: MockUsers.colleagues[4].id,
                authorDisplayName: MockUsers.colleagues[4].displayName,
                company: MockUsers.colleagues[4].company,
                likeCount: 45,
                createdAt: Date().addingTimeInterval(-5400)
            )
        ]
    }
    
    // MARK: - Celebratory Comments
    private static func celebratoryComments(for postId: UUID) -> [Comment] {
        return [
            Comment(
                postId: postId,
                content: "🎉🎉🎉 Hell yeah! This is huge for the team!",
                authorId: MockUsers.colleagues[1].id,
                authorDisplayName: MockUsers.colleagues[1].displayName,
                company: MockUsers.colleagues[1].company,
                likeCount: 89,
                isLikedByCreator: true,
                createdAt: Date().addingTimeInterval(-1200)
            ),
            Comment(
                postId: postId,
                content: "So well deserved! You all have been crushing it this quarter 💪",
                authorId: MockUsers.colleagues[0].id,
                authorDisplayName: MockUsers.colleagues[0].displayName,
                company: MockUsers.colleagues[0].company,
                likeCount: 67,
                isLikedByCreator: true,
                createdAt: Date().addingTimeInterval(-2400)
            ),
            Comment(
                postId: postId,
                content: "Finally some good news! When's the pizza party? 🍕",
                authorId: MockUsers.colleagues[2].id,
                authorDisplayName: MockUsers.colleagues[2].displayName,
                company: MockUsers.colleagues[2].company,
                likeCount: 134,
                createdAt: Date().addingTimeInterval(-3000)
            ),
            Comment(
                postId: postId,
                content: "This calls for drinks after work! Who's in?",
                authorId: MockUsers.colleagues[3].id,
                authorDisplayName: MockUsers.colleagues[3].displayName,
                company: MockUsers.colleagues[3].company,
                likeCount: 56,
                createdAt: Date().addingTimeInterval(-4800)
            ),
            Comment(
                postId: postId,
                content: "Proud to be part of this team! 🙌",
                authorId: MockUsers.colleagues[4].id,
                authorDisplayName: MockUsers.colleagues[4].displayName,
                company: MockUsers.colleagues[4].company,
                likeCount: 23,
                isLikedByCreator: false,
                createdAt: Date().addingTimeInterval(-6000)
            )
        ]
    }
    
    // MARK: - Mixed Comments
    private static func mixedComments(for postId: UUID) -> [Comment] {
        return [
            Comment(
                postId: postId,
                content: "Thanks for sharing this! Really helpful insights 👍",
                authorId: MockUsers.colleagues[0].id,
                authorDisplayName: MockUsers.colleagues[0].displayName,
                company: MockUsers.colleagues[0].company,
                likeCount: 12,
                isLikedByCreator: true,
                createdAt: Date().addingTimeInterval(-1800)
            ),
            Comment(
                postId: postId,
                content: "wait what? I had no idea about this",
                authorId: MockUsers.colleagues[5].id,
                authorDisplayName: nil,
                company: MockUsers.colleagues[5].company,
                isAnonymous: true,
                likeCount: 34,
                createdAt: Date().addingTimeInterval(-5400)
            ),
            Comment(
                postId: postId,
                content: "Good point! I'll definitely keep this in mind for next time",
                authorId: MockUsers.colleagues[2].id,
                authorDisplayName: MockUsers.colleagues[2].displayName,
                company: MockUsers.colleagues[2].company,
                likeCount: 8,
                createdAt: Date().addingTimeInterval(-7200)
            )
        ]
    }
    
    // MARK: - Helper Functions
    static func getCommentCount(for postId: UUID) -> Int {
        return getCommentsForPost(postId).count
    }

    static func createComment(
        postId: UUID,
        content: String,
        isAnonymous: Bool = false
    ) -> Comment {
        return Comment(
            postId: postId,
            content: content,
            authorId: MockUsers.currentUser.id,
            authorDisplayName: isAnonymous ? nil : MockUsers.currentUser.displayName,
            company: MockUsers.currentUser.company,
            isAnonymous: isAnonymous,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Mock Replies
    private static var cachedReplies: [UUID: [Comment]] = [:]

    static func getRepliesForComment(_ commentId: UUID) -> [Comment] {
        // Return cached replies if they exist
        if let cached = cachedReplies[commentId] {
            return cached
        }

        // Generate mock replies based on comment ID to simulate variety
        let commentSeed = abs(commentId.uuidString.hashValue) % 10
        let postId = UUID() // Dummy post ID for replies

        var replies: [Comment] = []

        // Generate 10-15 replies to test pagination
        let replyCount = 10 + (commentSeed % 6)

        for i in 0..<replyCount {
            let isAnonymous = i % 4 == 0 // Every 4th reply is anonymous
            let user = isAnonymous ? MockUsers.colleagues[5] : MockUsers.colleagues[i % MockUsers.colleagues.count]

            let contents = [
                "Thanks! Glad you found it helpful 😊",
                "Same here! This completely changed my perspective",
                "Could you share more details about this?",
                "100% this! We need more discussions like this",
                "Totally agree with this take 👍",
                "This is so true! I've been thinking the same thing",
                "Great point! Never thought of it that way",
                "Can confirm, this happened to me too",
                "I disagree, but I see where you're coming from",
                "Interesting perspective! Tell me more",
                "This! Exactly this! 🔥",
                "lol same energy",
                "wait really? that's wild",
                "Thanks for sharing this insight",
                "Appreciate you bringing this up"
            ]

            let reply = Comment(
                postId: postId,
                content: contents[i % contents.count],
                authorId: user.id,
                authorDisplayName: isAnonymous ? nil : user.displayName,
                company: user.company,
                isAnonymous: isAnonymous,
                likeCount: Int.random(in: 0...50),
                isLikedByCreator: i % 3 == 0,
                createdAt: Date().addingTimeInterval(-Double(i * 1800)),
                replyToCommentId: commentId,
                replyToBackendId: nil
            )

            replies.append(reply)
        }

        // Cache the replies
        cachedReplies[commentId] = replies
        return replies
    }

    static func getReplyCount(for commentId: UUID) -> Int {
        return getRepliesForComment(commentId).count
    }

    static func clearRepliesCache() {
        cachedReplies.removeAll()
    }
}
#endif
