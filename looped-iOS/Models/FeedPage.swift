import Foundation

struct FeedPage {
    let posts: [Post]
    let nextCursor: String?
    let feedRequestId: UUID?
}

enum FeedMode: String {
    case forYou = "for_you"
    case new = "new"
    case following = "following"
}
