import Foundation

struct TrendingPost: Identifiable {
    let id: UUID
    let imageName: String
    let title: String
    let subtitle: String

    init(id: UUID = UUID(), imageName: String, title: String, subtitle: String) {
        self.id = id
        self.imageName = imageName
        self.title = title
        self.subtitle = subtitle
    }
}

struct LoopCategory: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let memberCount: Int

    init(id: UUID = UUID(), title: String, description: String, memberCount: Int) {
        self.id = id
        self.title = title
        self.description = description
        self.memberCount = memberCount
    }
}

struct SearchGroup: Identifiable {
    let id: UUID
    let title: String
    let iconName: String
    let memberCount: Int

    init(id: UUID = UUID(), title: String, iconName: String, memberCount: Int) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.memberCount = memberCount
    }
}

struct SearchFilterOption: Identifiable, Equatable {
    let id: UUID
    let title: String
    let apiKey: String

    init(id: UUID = UUID(), title: String, apiKey: String) {
        self.id = id
        self.title = title
        self.apiKey = apiKey
    }
}

struct SearchResultPerson: Identifiable {
    let id: UUID
    let backendId: Int?
    let name: String
    let username: String
    let title: String
    let company: String
    let avatarURL: String?

    init(
        id: UUID = UUID(),
        backendId: Int? = nil,
        name: String,
        username: String,
        title: String,
        company: String,
        avatarURL: String?
    ) {
        self.id = id
        self.backendId = backendId
        self.name = name
        self.username = username
        self.title = title
        self.company = company
        self.avatarURL = avatarURL
    }
}

struct SearchResultPost: Identifiable {
    let id: UUID
    let content: String
    let authorName: String
    let timestamp: Date
    let reactionCount: Int

    init(
        id: UUID = UUID(),
        content: String,
        authorName: String,
        timestamp: Date,
        reactionCount: Int
    ) {
        self.id = id
        self.content = content
        self.authorName = authorName
        self.timestamp = timestamp
        self.reactionCount = reactionCount
    }
}

struct SearchResultLoop: Identifiable {
    let id: UUID
    let backendId: Int?
    let name: String
    let description: String
    let memberCount: Int

    init(
        id: UUID = UUID(),
        backendId: Int? = nil,
        name: String,
        description: String,
        memberCount: Int
    ) {
        self.id = id
        self.backendId = backendId
        self.name = name
        self.description = description
        self.memberCount = memberCount
    }
}
