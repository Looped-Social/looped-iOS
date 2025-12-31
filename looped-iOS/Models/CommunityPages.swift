import Foundation

struct CommunityPage {
    let items: [CommunitySummary]
    let nextCursor: String?
}

enum CommunityFollowOrder: String {
    case relevant
    case recent
}
