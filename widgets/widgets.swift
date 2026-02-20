import WidgetKit
import SwiftUI
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

private enum WidgetTheme {
    static let accent = Color("AccentColor")
    static let background = Color("WidgetBackground")
    static let cardBackground = Color(uiColor: .systemGray5)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let success = accent
}

private func resolvedRemoteURL(from rawValue: String?) -> URL? {
    let trimmed = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let normalized = trimmed.replacingOccurrences(of: " ", with: "%20")

    if let absolute = URL(string: normalized), let scheme = absolute.scheme?.lowercased(),
       scheme == "http" || scheme == "https" {
        return absolute
    }

    if normalized.hasPrefix("//") {
        return URL(string: "https:\(normalized)")
    }

    if normalized.hasPrefix("www.") {
        return URL(string: "https://\(normalized)")
    }

    if let relative = URL(string: normalized, relativeTo: WidgetSnapshotRepository.apiBaseURL())?.absoluteURL,
       let scheme = relative.scheme?.lowercased(),
       scheme == "http" || scheme == "https" {
        return relative
    }

    if let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
       let relative = URL(string: encoded, relativeTo: WidgetSnapshotRepository.apiBaseURL())?.absoluteURL,
       let scheme = relative.scheme?.lowercased(),
       scheme == "http" || scheme == "https" {
        return relative
    }

    return nil
}

private struct QuickActionsEntry: TimelineEntry {
    let date: Date
}

private struct InboxPulseEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotValue
    let imageDataByURL: [String: Data]
}

private struct ProfileStatsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotValue
    let imageDataByURL: [String: Data]
}

private struct TrendingPostEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotValue
    let imageDataByURL: [String: Data]
}

private struct LockScreenQuickActionEntry: TimelineEntry {
    let date: Date
}

private struct VerifiedCommunitiesEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotValue
    let selectedCommunityId: Int?
}

private struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(QuickActionsEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        let refreshAt = Calendar.current.date(byAdding: .minute, value: 45, to: .now) ?? .now
        completion(Timeline(entries: [QuickActionsEntry(date: .now)], policy: .after(refreshAt)))
    }
}

private struct InboxPulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> InboxPulseEntry {
        InboxPulseEntry(
            date: .now,
            snapshot: WidgetSnapshotValue(
                updatedAt: .now,
                serverTime: .now,
                snapshotTTLSeconds: 900,
                unreadMessageCount: 8,
                messageRequestCount: 2,
                unreadMentionCount: 3,
                profileStats: .init(),
                recentChats: [
                    .init(
                        conversationId: 101,
                        title: "Alex",
                        avatarThumbnailUrl: nil,
                        lastMessagePreview: "Can we ship this after standup?",
                        unreadCount: 2
                    ),
                    .init(
                        conversationId: 202,
                        title: "Design Team",
                        avatarThumbnailUrl: nil,
                        lastMessagePreview: "Updated mocks are in Figma.",
                        unreadCount: 0
                    )
                ],
                trendingPost: nil,
                verifiedCommunities: [],
                selectedCommunityId: nil
            ),
            imageDataByURL: [:]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (InboxPulseEntry) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            let imageURLs = snapshot.recentChats.compactMap { resolvedRemoteURL(from: $0.avatarThumbnailUrl) }
            let imageDataByURL = await WidgetRemoteImageLoader.loadDataByURL(for: imageURLs)
            completion(InboxPulseEntry(date: .now, snapshot: snapshot, imageDataByURL: imageDataByURL))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InboxPulseEntry>) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            let imageURLs = snapshot.recentChats.compactMap { resolvedRemoteURL(from: $0.avatarThumbnailUrl) }
            let imageDataByURL = await WidgetRemoteImageLoader.loadDataByURL(for: imageURLs)
            let refreshAfter = max(300, snapshot.snapshotTTLSeconds)
            let refreshAt = Date().addingTimeInterval(TimeInterval(refreshAfter))
            let entry = InboxPulseEntry(date: .now, snapshot: snapshot, imageDataByURL: imageDataByURL)
            completion(Timeline(entries: [entry], policy: .after(refreshAt)))
        }
    }
}

private struct VerifiedCommunitiesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> VerifiedCommunitiesEntry {
        VerifiedCommunitiesEntry(
            date: .now,
            snapshot: WidgetSnapshotValue(
                updatedAt: .now,
                serverTime: .now,
                snapshotTTLSeconds: 900,
                unreadMessageCount: 0,
                messageRequestCount: 0,
                unreadMentionCount: 0,
                profileStats: .init(),
                trendingPost: nil,
                verifiedCommunities: [
                    .init(id: 42, name: "Engineering", shortName: "Eng", memberCount: 612),
                    .init(id: 84, name: "Design", shortName: nil, memberCount: 164)
                ],
                selectedCommunityId: 42
            ),
            selectedCommunityId: 42
        )
    }

    func snapshot(for configuration: VerifiedCommunitySelectionIntent, in context: Context) async -> VerifiedCommunitiesEntry {
        let snapshot = await WidgetSummaryService.latestSnapshot()
        return VerifiedCommunitiesEntry(
            date: .now,
            snapshot: snapshot,
            selectedCommunityId: configuration.community?.id
        )
    }

    func timeline(for configuration: VerifiedCommunitySelectionIntent, in context: Context) async -> Timeline<VerifiedCommunitiesEntry> {
        let snapshot = await WidgetSummaryService.latestSnapshot()
        let refreshAfter = max(300, snapshot.snapshotTTLSeconds)
        let refreshAt = Date().addingTimeInterval(TimeInterval(refreshAfter))
        let entry = VerifiedCommunitiesEntry(
            date: .now,
            snapshot: snapshot,
            selectedCommunityId: configuration.community?.id
        )
        return Timeline(entries: [entry], policy: .after(refreshAt))
    }
}

private struct ProfileStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProfileStatsEntry {
        ProfileStatsEntry(
            date: .now,
            snapshot: WidgetSnapshotValue(
                updatedAt: .now,
                serverTime: .now,
                snapshotTTLSeconds: 900,
                unreadMessageCount: 0,
                messageRequestCount: 0,
                unreadMentionCount: 0,
                profileStats: .init(followers: 210, following: 98, likesReceived: 1840),
                profileSummary: .init(
                    displayName: "Jane Doe",
                    avatarThumbnailUrl: nil,
                    specialization: "iOS Engineer",
                    primaryCommunityName: "Engineering"
                ),
                trendingPost: nil,
                verifiedCommunities: [],
                selectedCommunityId: nil
            ),
            imageDataByURL: [:]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ProfileStatsEntry) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            let imageURLs = [resolvedRemoteURL(from: snapshot.profileSummary?.avatarThumbnailUrl)].compactMap { $0 }
            let imageDataByURL = await WidgetRemoteImageLoader.loadDataByURL(for: imageURLs)
            completion(ProfileStatsEntry(date: .now, snapshot: snapshot, imageDataByURL: imageDataByURL))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProfileStatsEntry>) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            let imageURLs = [resolvedRemoteURL(from: snapshot.profileSummary?.avatarThumbnailUrl)].compactMap { $0 }
            let imageDataByURL = await WidgetRemoteImageLoader.loadDataByURL(for: imageURLs)
            let refreshAfter = max(300, snapshot.snapshotTTLSeconds)
            let refreshAt = Date().addingTimeInterval(TimeInterval(refreshAfter))
            let entry = ProfileStatsEntry(date: .now, snapshot: snapshot, imageDataByURL: imageDataByURL)
            completion(Timeline(entries: [entry], policy: .after(refreshAt)))
        }
    }
}

private struct TrendingPostProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrendingPostEntry {
        TrendingPostEntry(
            date: .now,
            snapshot: WidgetSnapshotValue(
                updatedAt: .now,
                serverTime: .now,
                snapshotTTLSeconds: 900,
                unreadMessageCount: 0,
                messageRequestCount: 0,
                unreadMentionCount: 0,
                profileStats: .init(),
                trendingPost: .init(
                    postId: 42,
                    communityName: "Engineering",
                    contentPreview: "We're rolling out a new launch plan this afternoon. Thoughts on cadence and docs?",
                    likeCount: 124,
                    commentCount: 38,
                    mediaThumbnailUrl: nil
                ),
                verifiedCommunities: [],
                selectedCommunityId: nil
            ),
            imageDataByURL: [:]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TrendingPostEntry) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            let imageURLs = [resolvedRemoteURL(from: snapshot.trendingPost?.mediaThumbnailUrl)].compactMap { $0 }
            let imageDataByURL = await WidgetRemoteImageLoader.loadDataByURL(for: imageURLs)
            completion(TrendingPostEntry(date: .now, snapshot: snapshot, imageDataByURL: imageDataByURL))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrendingPostEntry>) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            let imageURLs = [resolvedRemoteURL(from: snapshot.trendingPost?.mediaThumbnailUrl)].compactMap { $0 }
            let imageDataByURL = await WidgetRemoteImageLoader.loadDataByURL(for: imageURLs)
            let refreshAfter = max(300, snapshot.snapshotTTLSeconds)
            let refreshAt = Date().addingTimeInterval(TimeInterval(refreshAfter))
            let entry = TrendingPostEntry(date: .now, snapshot: snapshot, imageDataByURL: imageDataByURL)
            completion(Timeline(entries: [entry], policy: .after(refreshAt)))
        }
    }
}

private enum WidgetRemoteImageLoader {
    static func loadDataByURL(for urls: [URL]) async -> [String: Data] {
        let deduped = Array(Set(urls.map(\.absoluteString))).compactMap(URL.init(string:))
        guard !deduped.isEmpty else { return [:] }

        return await withTaskGroup(of: (String, Data?).self, returning: [String: Data].self) { group in
            for url in deduped {
                group.addTask {
                    let data = await fetchImageData(url: url)
                    return (url.absoluteString, data)
                }
            }

            var output: [String: Data] = [:]
            for await (key, data) in group {
                if let data {
                    output[key] = data
                }
            }
            return output
        }
    }

    private static func fetchImageData(url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                #if DEBUG
                print("WIDGET_IMAGE_FETCH non-http response url=\(url.absoluteString)")
                #endif
                return nil
            }
            guard 200 ... 299 ~= http.statusCode else {
                #if DEBUG
                print("WIDGET_IMAGE_FETCH failed status=\(http.statusCode) url=\(url.absoluteString)")
                #endif
                return nil
            }
            return downsampledImageData(from: data, maxPixelSize: 900) ?? data
        } catch {
            #if DEBUG
            print("WIDGET_IMAGE_FETCH error=\(error.localizedDescription) url=\(url.absoluteString)")
            #endif
            return nil
        }
    }

    private static func downsampledImageData(from data: Data, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [NSString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        #if canImport(UIKit)
        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: 0.88)
        #else
        return nil
        #endif
    }
}

private struct LockScreenQuickActionProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenQuickActionEntry {
        LockScreenQuickActionEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenQuickActionEntry) -> Void) {
        completion(LockScreenQuickActionEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenQuickActionEntry>) -> Void) {
        let refreshAt = Calendar.current.date(byAdding: .hour, value: 12, to: .now) ?? .now
        completion(Timeline(entries: [LockScreenQuickActionEntry(date: .now)], policy: .after(refreshAt)))
    }
}

private struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .containerBackground(for: .widget) {
                ZStack {
                    LinearGradient(
                        colors: [WidgetTheme.background, WidgetTheme.background.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
    }
}

private struct WidgetSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(WidgetTheme.textPrimary)
    }
}

private struct QuickActionItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let url: URL
}

private let quickActions: [QuickActionItem] = [
    .init(id: "home", title: "Home", symbol: "house.fill", url: WidgetDeepLink.home),
    .init(id: "messages", title: "Chat", symbol: "bubble.left.and.bubble.right.fill", url: WidgetDeepLink.messages),
    .init(id: "search", title: "Search", symbol: "magnifyingglass", url: WidgetDeepLink.search),
    .init(id: "post", title: "Post", symbol: "square.and.pencil", url: WidgetDeepLink.createPost)
]

private let quickActionsMedium: [QuickActionItem] = quickActions.filter { $0.id != "search" }

private struct QuickActionButton: View {
    let action: QuickActionItem
    let compact: Bool

    var body: some View {
        Link(destination: action.url) {
            VStack(spacing: compact ? 4 : 6) {
                Image(systemName: action.symbol)
                    .font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                Text(action.title)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 42 : 56)
            .padding(.vertical, compact ? 2 : 4)
            .background(
                RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                    .fill(WidgetTheme.cardBackground)
            )
        }
    }
}

private struct QuickActionsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: QuickActionsProvider.Entry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        .padding(12)
        .modifier(WidgetBackgroundModifier())
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetSectionTitle(title: "Shortcuts")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(quickActions) { action in
                    QuickActionButton(action: action, compact: true)
                }
            }
        }
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetSectionTitle(title: "Shortcuts")

            Link(destination: WidgetDeepLink.search) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WidgetTheme.textPrimary)
                    Text("Search on Looped")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(WidgetTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(WidgetTheme.cardBackground)
                )
            }

            HStack(spacing: 8) {
                ForEach(quickActionsMedium) { action in
                    QuickActionButton(action: action, compact: false)
                }
            }
        }
    }
}

private struct InboxPulseWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: InboxPulseProvider.Entry

    private var recentChats: [WidgetSnapshotValue.RecentChat] {
        Array(
            entry.snapshot.recentChats
                .filter { $0.conversationId > 0 }
                .prefix(3)
        )
    }

    private var totalInboxCount: Int {
        entry.snapshot.unreadMessageCount + entry.snapshot.messageRequestCount
    }

    private var fallbackDestination: URL? {
        if family == .accessoryRectangular {
            return WidgetDeepLink.messages
        }
        return recentChats.isEmpty ? WidgetDeepLink.messages : nil
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                accessoryRectangularLayout
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        .padding(12)
        .modifier(WidgetBackgroundModifier())
        .widgetURL(fallbackDestination)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetSectionTitle(title: "Messages")

            Text("\(totalInboxCount)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.textPrimary)
            Text(totalInboxCount == 1 ? "item waiting" : "items waiting")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)

            HStack(spacing: 8) {
                miniBadge(title: "Mentions", value: entry.snapshot.unreadMentionCount)
                miniBadge(title: "Req", value: entry.snapshot.messageRequestCount)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetSectionTitle(title: "Messages")

            if recentChats.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No recent chats yet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WidgetTheme.textPrimary)
                    Text("Open Messages in Looped to refresh this widget.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(recentChats) { chat in
                        Link(destination: recentChatDestination(for: chat)) {
                            recentChatColumn(chat: chat)
                        }
                    }
                }
            }
        }
    }

    private func recentChatDestination(for chat: WidgetSnapshotValue.RecentChat) -> URL {
        guard chat.conversationId > 0 else { return WidgetDeepLink.messages }
        return WidgetDeepLink.conversation(chat.conversationId)
    }

    private var accessoryRectangularLayout: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Messages")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                Text("U \(totalInboxCount) - R \(entry.snapshot.messageRequestCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func recentChatColumn(chat: WidgetSnapshotValue.RecentChat) -> some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                chatAvatar(urlString: chat.avatarThumbnailUrl, size: 50)
                if chat.unreadCount > 0 {
                    Text("\(chat.unreadCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(WidgetTheme.accent)
                        )
                        .offset(x: 8, y: -5)
                }
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .center, spacing: 1) {
                Text(chat.title.isEmpty ? "Chat" : chat.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)

                Text(chat.lastMessagePreview.isEmpty ? "Open chat to continue." : chat.lastMessagePreview)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func chatAvatar(urlString: String?, size avatarSize: CGFloat) -> some View {
        if let url = resolvedRemoteURL(from: urlString),
           let data = entry.imageDataByURL[url.absoluteString],
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())
        } else {
            fallbackChatAvatar
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())
        }
    }

    private var fallbackChatAvatar: some View {
        ZStack {
            Circle()
                .fill(WidgetTheme.cardBackground)
            Image(systemName: "person.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
    }

    private func miniBadge(title: String, value: Int) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(WidgetTheme.accent)
                .frame(width: 6, height: 6)
            Text("\(title) \(max(0, value))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
    }
}

private struct VerifiedCommunitiesWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: VerifiedCommunitiesProvider.Entry

    private var resolvedCommunity: WidgetSnapshotValue.VerifiedCommunity? {
        if let explicitCommunityId = entry.selectedCommunityId,
           let explicit = entry.snapshot.verifiedCommunities.first(where: { $0.id == explicitCommunityId }) {
            return explicit
        }
        if let appSelectedCommunityId = entry.snapshot.selectedCommunityId,
           let appSelected = entry.snapshot.verifiedCommunities.first(where: { $0.id == appSelectedCommunityId }) {
            return appSelected
        }
        return entry.snapshot.verifiedCommunities.first
    }

    private var totalVerifiedCount: Int {
        entry.snapshot.verifiedCommunities.count
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        .padding(12)
        .modifier(WidgetBackgroundModifier())
        .widgetURL(resolvedCommunity.map { WidgetDeepLink.community($0.id) } ?? WidgetDeepLink.search)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetSectionTitle(title: "Verified")

            if let community = resolvedCommunity {
                Text(community.shortName ?? community.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(2)
                Text("\(community.memberCount) members")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                if community.newActivityCount > 0 {
                    Text("\(community.newActivityCount) new")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetTheme.accent)
                }
            } else {
                Text("No verified communities")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                Text("Open app to verify communities and refresh.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
            }

            Text("Verified in \(totalVerifiedCount)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.success)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetSectionTitle(title: "Verified Communities")

            if let community = resolvedCommunity {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(WidgetTheme.cardBackground)
                        .overlay(
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(WidgetTheme.success)
                        )
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(community.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetTheme.textPrimary)
                            .lineLimit(2)
                        Text("\(community.memberCount) members")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WidgetTheme.textSecondary)
                        if community.newActivityCount > 0 {
                            Text("\(community.newActivityCount) new activity")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(WidgetTheme.accent)
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Text("You are not verified in any communities yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(3)
                Text("Open app to verify communities and update this widget.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(2)
            }

            Text("Verified in \(totalVerifiedCount) \(totalVerifiedCount == 1 ? "community" : "communities")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.success)
        }
    }
}

private struct ProfileStatsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: ProfileStatsProvider.Entry

    private var profileSummary: WidgetSnapshotValue.ProfileSummary? {
        guard let raw = entry.snapshot.profileSummary else { return nil }
        let displayName = raw.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let specialization = raw.specialization?.trimmingCharacters(in: .whitespacesAndNewlines)
        let community = raw.primaryCommunityName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatar = raw.avatarThumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayName.isEmpty && (specialization ?? "").isEmpty && (community ?? "").isEmpty && (avatar ?? "").isEmpty {
            return nil
        }
        return .init(
            displayName: displayName,
            avatarThumbnailUrl: (avatar?.isEmpty == false) ? avatar : nil,
            specialization: (specialization?.isEmpty == false) ? specialization : nil,
            primaryCommunityName: (community?.isEmpty == false) ? community : nil
        )
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            default:
                mediumLayout
            }
        }
        .padding(12)
        .modifier(WidgetBackgroundModifier())
        .widgetURL(WidgetDeepLink.profile)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetSectionTitle(title: "Profile")
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.snapshot.profileStats.likesReceived)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetTheme.textPrimary)
                    Text("likes received")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetTheme.textSecondary)
                }
                Spacer(minLength: 0)
                profileAvatar(urlString: profileSummary?.avatarThumbnailUrl, size: 40)
            }

            HStack(spacing: 10) {
                statPill(label: "Followers", value: entry.snapshot.profileStats.followers)
                statPill(label: "Following", value: entry.snapshot.profileStats.following)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetSectionTitle(title: "Profile")

            HStack(alignment: .center, spacing: 10) {
                profileAvatar(urlString: profileSummary?.avatarThumbnailUrl, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(profileDisplayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetTheme.textPrimary)
                        .lineLimit(1)

                    if let specialization = profileSummary?.specialization {
                        Text(specialization)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WidgetTheme.textSecondary)
                            .lineLimit(1)
                    }

                    if let community = profileSummary?.primaryCommunityName {
                        Text(community)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(WidgetTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                compactProfileMetric(title: "Followers", value: entry.snapshot.profileStats.followers)
                compactProfileMetric(title: "Following", value: entry.snapshot.profileStats.following)
                compactProfileMetric(title: "Likes", value: entry.snapshot.profileStats.likesReceived)
            }
        }
    }

    private var profileDisplayName: String {
        let displayName = profileSummary?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return displayName.isEmpty ? "Your Profile" : displayName
    }

    private func compactProfileMetric(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
            Text("\(max(0, value))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func profileAvatar(urlString: String?, size avatarSize: CGFloat) -> some View {
        if let url = resolvedRemoteURL(from: urlString),
           let data = entry.imageDataByURL[url.absoluteString],
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())
        } else {
            fallbackAvatar
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(Circle())
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(WidgetTheme.cardBackground)
            Image(systemName: "person.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
    }

    private func statPill(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
            Text("\(max(0, value))")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(WidgetTheme.textPrimary)
        }
    }
}

private struct TrendingPostWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: TrendingPostProvider.Entry

    private var post: WidgetSnapshotValue.TrendingPost? {
        guard let value = entry.snapshot.trendingPost, value.postId > 0 else { return nil }
        return value
    }

    private func hasMedia(_ post: WidgetSnapshotValue.TrendingPost) -> Bool {
        guard let raw = post.mediaThumbnailUrl?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !raw.isEmpty
    }

    private func previewText(for post: WidgetSnapshotValue.TrendingPost) -> String {
        let trimmed = post.contentPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Open this post in Looped to join the conversation." : trimmed
    }

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                largeLayout
            default:
                mediumLayout
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(post.map { WidgetDeepLink.post($0.postId) })
    }

    private var mediumLayout: some View {
        Group {
            if let post {
                if hasMedia(post) {
                    mediaDominantCard(post: post, contentLineLimit: 2)
                } else {
                    textDominantCard(post: post, titleSize: 16, lineLimit: 4, includeCommentHint: false)
                }
            } else {
                emptyTrendingState
            }
        }
    }

    private var largeLayout: some View {
        Group {
            if let post {
                if hasMedia(post) {
                    mediaDominantCard(post: post, contentLineLimit: 3)
                } else {
                    textDominantCard(post: post, titleSize: 18, lineLimit: 8, includeCommentHint: true)
                }
            } else {
                emptyTrendingState
            }
        }
    }

    private var emptyTrendingState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trending Post")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
            Text("No trending posts yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WidgetTheme.textPrimary)
            Text("Open app to get the latest posts and update this widget.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mediaDominantCard(post: WidgetSnapshotValue.TrendingPost, contentLineLimit: Int) -> some View {
        return GeometryReader { proxy in
            let textBandHeight: CGFloat = family == .systemLarge ? 94 : 82
            let mediaHeight = max(0, proxy.size.height - textBandHeight)

            VStack(spacing: 0) {
                trendingMediaBackground(urlString: post.mediaThumbnailUrl)
                    .frame(width: proxy.size.width, height: mediaHeight)
                    .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Trending in \(post.communityName)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetTheme.textSecondary)
                        .lineLimit(1)
                    Text(previewText(for: post))
                        .font(.system(size: family == .systemLarge ? 14 : 13, weight: .semibold))
                        .foregroundStyle(WidgetTheme.textPrimary)
                        .lineLimit(contentLineLimit)
                    HStack(spacing: 8) {
                        overlayMetricChip(symbol: "heart.fill", value: post.likeCount)
                        overlayMetricChip(symbol: "bubble.right.fill", value: post.commentCount)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, minHeight: textBandHeight, alignment: .topLeading)
                .background(WidgetTheme.background)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipped()
        }
    }

    private func textDominantCard(
        post: WidgetSnapshotValue.TrendingPost,
        titleSize: CGFloat,
        lineLimit: Int,
        includeCommentHint: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trending in \(post.communityName)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
                .lineLimit(1)
            Text(previewText(for: post))
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(WidgetTheme.textPrimary)
                .lineLimit(lineLimit)
            HStack(spacing: 10) {
                metricChip(symbol: "heart.fill", value: post.likeCount)
                metricChip(symbol: "bubble.right.fill", value: post.commentCount)
                Spacer(minLength: 0)
            }
            commentsPreview(post: post, includeCommentHint: includeCommentHint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func metricChip(symbol: String, value: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
            Text("\(max(0, value))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private func overlayMetricChip(symbol: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
            Text("\(max(0, value))")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(WidgetTheme.textPrimary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(WidgetTheme.cardBackground)
        )
    }

    @ViewBuilder
    private func trendingMediaBackground(urlString: String?) -> some View {
        if let url = resolvedRemoteURL(from: urlString),
           let data = entry.imageDataByURL[url.absoluteString],
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            placeholderImage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var placeholderImage: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [WidgetTheme.accent.opacity(0.18), WidgetTheme.accent.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "text.below.photo")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
    }

    @ViewBuilder
    private func commentsPreview(post: WidgetSnapshotValue.TrendingPost, includeCommentHint: Bool) -> some View {
        let lines = commentPreviewLines(for: post, includeCommentHint: includeCommentHint)
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Comments")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textSecondary)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(WidgetTheme.textSecondary)
                        Text(line)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WidgetTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func commentPreviewLines(
        for post: WidgetSnapshotValue.TrendingPost,
        includeCommentHint: Bool
    ) -> [String] {
        let comments = max(0, post.commentCount)
        if comments == 0 {
            return includeCommentHint
                ? ["No comments yet. Be first to reply."]
                : []
        }
        if comments == 1 {
            return ["1 comment in this thread", "Tap to read the reply"]
        }
        return includeCommentHint
            ? ["\(comments) comments in this thread", "Open post to read top replies"]
            : ["\(comments) comments in this thread"]
    }
}

private struct LockScreenQuickActionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let title: String
    let symbol: String
    let destination: URL

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
            case .accessoryRectangular:
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
            default:
                Label(title, systemImage: symbol)
            }
        }
        .foregroundStyle(WidgetTheme.textPrimary)
        .widgetURL(destination)
    }
}

struct QuickActionsWidget: Widget {
    let kind = "com.mylooped.looped.widgets.quick-actions"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Open Home, Chat, Search, or start a new post.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct InboxPulseWidget: Widget {
    let kind = "com.mylooped.looped.widgets.inbox-pulse"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InboxPulseProvider()) { entry in
            InboxPulseWidgetView(entry: entry)
        }
        .configurationDisplayName("Messages")
        .description("Recent chats with unread activity.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}

struct VerifiedCommunitiesWidget: Widget {
    let kind = "com.mylooped.looped.widgets.verified-communities"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: VerifiedCommunitySelectionIntent.self,
            provider: VerifiedCommunitiesProvider()
        ) { entry in
            VerifiedCommunitiesWidgetView(entry: entry)
        }
        .configurationDisplayName("Verified Communities")
        .description("Jump to a selected verified community or follow the app default.")
        .supportedFamilies([.systemMedium])
    }
}

struct ProfileStatsWidget: Widget {
    let kind = "com.mylooped.looped.widgets.profile-stats"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProfileStatsProvider()) { entry in
            ProfileStatsWidgetView(entry: entry)
        }
        .configurationDisplayName("Profile Stats")
        .description("Followers, following, and likes received.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TrendingPostWidget: Widget {
    let kind = "com.mylooped.looped.widgets.trending-post"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrendingPostProvider()) { entry in
            TrendingPostWidgetView(entry: entry)
        }
        .configurationDisplayName("Trending Post")
        .description("See what is trending and jump straight into the post.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct LockScreenCreateWidget: Widget {
    let kind = "com.mylooped.looped.widgets.lockscreen-create"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenQuickActionProvider()) { _ in
            LockScreenQuickActionWidgetView(
                title: "Create",
                symbol: "plus",
                destination: WidgetDeepLink.createPost
            )
        }
        .configurationDisplayName("Create Post")
        .description("Quickly start a new post from the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenSearchWidget: Widget {
    let kind = "com.mylooped.looped.widgets.lockscreen-search"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenQuickActionProvider()) { _ in
            LockScreenQuickActionWidgetView(
                title: "Search",
                symbol: "magnifyingglass",
                destination: WidgetDeepLink.search
            )
        }
        .configurationDisplayName("Search")
        .description("Open search from the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenChatWidget: Widget {
    let kind = "com.mylooped.looped.widgets.lockscreen-chat"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenQuickActionProvider()) { _ in
            LockScreenQuickActionWidgetView(
                title: "Chat",
                symbol: "paperplane.fill",
                destination: WidgetDeepLink.messages
            )
        }
        .configurationDisplayName("Chat")
        .description("Jump into messages from the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
