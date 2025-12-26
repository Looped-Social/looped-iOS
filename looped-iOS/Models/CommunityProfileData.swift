import Foundation

struct CommunityProfileData: Identifiable, Equatable {
    let id: Int
    var name: String
    var description: String
    var kind: CommunityKind
    var memberCount: Int
    var imageUrl: String?
    var isFollowing: Bool
}

extension CommunityProfileData {
    init(community: CommunitySearchResult) {
        self.id = community.id
        self.name = community.name
        self.description = community.description
        self.kind = community.kind
        self.memberCount = community.memberCount
        self.imageUrl = community.imageUrl
        self.isFollowing = community.isFollowing ?? false
    }

    init(summary: CommunitySummary, description: String = "", imageUrl: String? = nil) {
        self.id = summary.id
        self.name = summary.name
        self.description = description
        self.kind = summary.kind
        self.memberCount = summary.memberCount
        self.imageUrl = imageUrl
        self.isFollowing = true
    }

    init?(loop: SearchResultLoop) {
        guard let backendId = loop.backendId else { return nil }
        self.id = backendId
        self.name = loop.name
        self.description = loop.description
        self.kind = .unknown
        self.memberCount = loop.memberCount
        self.imageUrl = loop.imageUrl
        self.isFollowing = false
    }
}
