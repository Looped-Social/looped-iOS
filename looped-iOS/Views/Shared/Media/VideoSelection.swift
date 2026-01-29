import Foundation

struct VideoSelection: Identifiable {
    let id = UUID()
    let url: String
    let thumbnailUrl: String?
    let authorName: String?
    let authorImageUrl: String?
    let communityName: String?
    let caption: String?
    let inlineViewModel: InlineVideoPlayerViewModel?

    init(
        url: String,
        thumbnailUrl: String? = nil,
        authorName: String? = nil,
        authorImageUrl: String? = nil,
        communityName: String? = nil,
        caption: String? = nil,
        inlineViewModel: InlineVideoPlayerViewModel? = nil
    ) {
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.authorName = authorName
        self.authorImageUrl = authorImageUrl
        self.communityName = communityName
        self.caption = caption
        self.inlineViewModel = inlineViewModel
    }
}
