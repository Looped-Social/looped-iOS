import WidgetKit
import SwiftUI
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

private struct QuickActionsEntry: TimelineEntry {
    let date: Date
}

private struct InboxPulseEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotValue
}

private struct ProfileStatsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotValue
}

private struct TrendingPostEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotValue
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
                trendingPost: nil,
                verifiedCommunities: [],
                selectedCommunityId: nil
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (InboxPulseEntry) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            completion(InboxPulseEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InboxPulseEntry>) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            let refreshAfter = max(300, snapshot.snapshotTTLSeconds)
            let refreshAt = Date().addingTimeInterval(TimeInterval(refreshAfter))
            let entry = InboxPulseEntry(date: .now, snapshot: snapshot)
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
                trendingPost: nil,
                verifiedCommunities: [],
                selectedCommunityId: nil
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ProfileStatsEntry) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            completion(ProfileStatsEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProfileStatsEntry>) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            let refreshAfter = max(300, snapshot.snapshotTTLSeconds)
            let refreshAt = Date().addingTimeInterval(TimeInterval(refreshAfter))
            let entry = ProfileStatsEntry(date: .now, snapshot: snapshot)
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
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TrendingPostEntry) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            completion(TrendingPostEntry(date: .now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrendingPostEntry>) -> Void) {
        Task {
            let snapshot = await WidgetSummaryService.latestSnapshot()
            let refreshAfter = max(300, snapshot.snapshotTTLSeconds)
            let refreshAt = Date().addingTimeInterval(TimeInterval(refreshAfter))
            let entry = TrendingPostEntry(date: .now, snapshot: snapshot)
            completion(Timeline(entries: [entry], policy: .after(refreshAt)))
        }
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

                    Circle()
                        .fill(WidgetTheme.accent.opacity(0.12))
                        .frame(width: 170, height: 170)
                        .offset(x: 65, y: -75)

                    VStack {
                        HStack {
                            Spacer(minLength: 0)
                            Image("logo-widget")
                                .resizable()
                                .renderingMode(.original)
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .accessibilityHidden(true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
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
    .init(id: "messages", title: "Inbox", symbol: "bubble.left.and.bubble.right.fill", url: WidgetDeepLink.messages),
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

    private var totalInboxCount: Int {
        entry.snapshot.unreadMessageCount + entry.snapshot.messageRequestCount
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
        .widgetURL(WidgetDeepLink.messages)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetSectionTitle(title: "Inbox")

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
            WidgetSectionTitle(title: "Inbox")

            HStack(spacing: 8) {
                pulseMetric(title: "Unread", value: entry.snapshot.unreadMessageCount)
                pulseMetric(title: "Requests", value: entry.snapshot.messageRequestCount)
                pulseMetric(title: "Mentions", value: entry.snapshot.unreadMentionCount)
            }

            Text("Tap to open messages")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
    }

    private var accessoryRectangularLayout: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Inbox")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                Text("\(totalInboxCount) unread - \(entry.snapshot.unreadMentionCount) mentions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func pulseMetric(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
            Text("\(max(0, value))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.cardBackground)
        )
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
                Text("Tap to search and verify")
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
                Text("Tap to open Search and start verification.")
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
            Text("\(entry.snapshot.profileStats.likesReceived)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.textPrimary)
            Text("likes received")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)

            HStack(spacing: 10) {
                statPill(label: "Followers", value: entry.snapshot.profileStats.followers)
                statPill(label: "Following", value: entry.snapshot.profileStats.following)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetSectionTitle(title: "Profile Stats")

            HStack(spacing: 8) {
                profileMetric(title: "Followers", value: entry.snapshot.profileStats.followers)
                profileMetric(title: "Following", value: entry.snapshot.profileStats.following)
                profileMetric(title: "Likes", value: entry.snapshot.profileStats.likesReceived)
            }

            Text("Tap to open profile")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
    }

    private func profileMetric(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
            Text("\(max(0, value))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.cardBackground)
        )
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

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                largeLayout
            default:
                mediumLayout
            }
        }
        .padding(12)
        .modifier(WidgetBackgroundModifier())
        .widgetURL(post.map { WidgetDeepLink.post($0.postId) } ?? WidgetDeepLink.home)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetSectionTitle(title: "Trending Post")

            if let post {
                HStack(spacing: 10) {
                    trendingImage(urlString: post.mediaThumbnailUrl, size: CGSize(width: 86, height: 86))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("in \(post.communityName)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(WidgetTheme.textSecondary)
                            .lineLimit(1)
                        Text(post.contentPreview)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(WidgetTheme.textPrimary)
                            .lineLimit(4)
                        HStack(spacing: 10) {
                            metricChip(symbol: "heart.fill", value: post.likeCount)
                            metricChip(symbol: "bubble.right.fill", value: post.commentCount)
                        }
                    }
                }
            } else {
                emptyTrendingState
            }
        }
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetSectionTitle(title: "Trending Post")

            if let post {
                trendingImage(urlString: post.mediaThumbnailUrl, size: CGSize(width: 0, height: 128))

                Text("in \(post.communityName)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(1)

                Text(post.contentPreview)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(5)

                HStack(spacing: 10) {
                    metricChip(symbol: "heart.fill", value: post.likeCount)
                    metricChip(symbol: "bubble.right.fill", value: post.commentCount)
                    Spacer(minLength: 0)
                    Text("Tap to open")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetTheme.textSecondary)
                }
            } else {
                emptyTrendingState
            }
        }
    }

    private var emptyTrendingState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No trending post yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WidgetTheme.textPrimary)
            Text("Open Looped to refresh.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        .background(
            Capsule()
                .fill(WidgetTheme.cardBackground)
        )
    }

    @ViewBuilder
    private func trendingImage(urlString: String?, size: CGSize) -> some View {
        let fixedWidth = size.width > 0 ? size.width : nil
        let fixedHeight = size.height
        if let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            sizedTrendingFrame(
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderImage
                    }
                },
                width: fixedWidth,
                height: fixedHeight
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            sizedTrendingFrame(placeholderImage, width: fixedWidth, height: fixedHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func sizedTrendingFrame<Content: View>(_ content: Content, width: CGFloat?, height: CGFloat) -> some View {
        if let width {
            content.frame(width: width, height: height)
        } else {
            content.frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.cardBackground)
            Image(systemName: "text.below.photo")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
        }
    }
}

struct QuickActionsWidget: Widget {
    let kind = "com.mylooped.looped.widgets.quick-actions"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Open Home, Messages, Search, or start a new post.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct InboxPulseWidget: Widget {
    let kind = "com.mylooped.looped.widgets.inbox-pulse"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InboxPulseProvider()) { entry in
            InboxPulseWidgetView(entry: entry)
        }
        .configurationDisplayName("Inbox")
        .description("Unread DMs, requests, and mentions at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
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
        .supportedFamilies([.systemSmall, .systemMedium])
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
    }
}
