import SwiftUI

struct RepostersListView: View {
    @Environment(\.dismiss) private var dismiss
    let postId: Int?
    let totalCount: Int
    private let feedService: FeedServiceProtocol
    private let userService: UserServiceProtocol
    @State private var canPop: Bool?
    @State private var displayedUsers: [RepostBannerUser]
    @State private var nextCursor: String?
    @State private var hasLoadedRemote = false
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var fallbackUsers: [Int: User] = [:]
    @State private var attemptedFallbackUserIds: Set<Int> = []

    init(
        postId: Int?,
        users: [RepostBannerUser],
        totalCount: Int,
        feedService: FeedServiceProtocol = FeedService(),
        userService: UserServiceProtocol = UserService()
    ) {
        self.postId = postId
        self.totalCount = totalCount
        self.feedService = feedService
        self.userService = userService
        _displayedUsers = State(initialValue: Self.dedupe(users))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if displayedUsers.isEmpty {
                    emptyState
                } else {
                    ForEach(displayedUsers) { user in
                        NavigationLink(destination: UserProfileView(userId: user.userId)) {
                            HStack(spacing: 12) {
                                ProfileAvatarView(imageURL: avatarURL(for: user), size: 44)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayName(for: user))
                                        .font(.loopedBodyMedium)
                                        .foregroundColor(.loopedTextPrimary)

                                    Text(handleText(for: user))
                                        .font(.loopedSubBodyRegular)
                                        .foregroundColor(.loopedTextSecondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onAppear {
                            Task { await loadMoreIfNeeded(currentUser: user) }
                        }

                        Divider()
                            .background(Color.loopedMutedBackground)
                            .padding(.leading, 72)
                    }

                    if totalCount > displayedUsers.count {
                        Text("And \(max(totalCount - displayedUsers.count, 0)) more")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                            .padding(.top, 12)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if isLoadingMore {
                        LoopedInlineLoadingIndicator()
                            .padding(.top, 8)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Reposts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { toolbarContent }
        .background(NavigationCanPopReader(canPop: $canPop))
        .overlay {
            if isLoading && displayedUsers.isEmpty {
                ProgressView()
                    .tint(.loopedPrimary)
            }
        }
        .task(id: postId) {
            await loadInitialIfNeeded()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.2.squarepath")
                .font(.loopedCustom(.semibold, size: 32))
                .foregroundColor(.loopedSecondary)

            Text(totalCount == 0 ? "No reposts yet" : "Reposted by \(totalCount) people")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Text(totalCount == 0 ? "When someone reposts, they’ll show up here." : "The full list isn’t available yet.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if canPop == false {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.loopedCustom(.semibold, size: 16))
                        .foregroundColor(.loopedTextSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
    }

    private func displayName(for repostUser: RepostBannerUser) -> String {
        if let fullName = nonEmpty(repostUser.displayName) {
            return fullName
        }
        if let fullName = nonEmpty(fallbackUsers[repostUser.userId]?.displayName) {
            return fullName
        }
        return normalizedHandle(repostUser.username)
    }

    private func handleText(for repostUser: RepostBannerUser) -> String {
        if let handle = nonEmpty(repostUser.handle) {
            return "@\(normalizedHandle(handle))"
        }
        if let handle = nonEmpty(fallbackUsers[repostUser.userId]?.handle) {
            return "@\(normalizedHandle(handle))"
        }
        return "@\(normalizedHandle(repostUser.username))"
    }

    private func avatarURL(for repostUser: RepostBannerUser) -> String? {
        if let url = nonEmpty(repostUser.profileImageURL) {
            return url
        }
        return nonEmpty(fallbackUsers[repostUser.userId]?.profileImageURL)
    }

    private func normalizedHandle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    private func loadInitialIfNeeded() async {
        guard !hasLoadedRemote else { return }
        hasLoadedRemote = true
        guard let postId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await feedService.fetchReposters(postId: postId, limit: 20, cursor: nil)
            if !page.items.isEmpty {
                displayedUsers = Self.dedupe(page.items)
            }
            nextCursor = page.nextCursor
            await hydrateMissingUsersIfNeeded(for: displayedUsers)
        } catch {
            nextCursor = nil
            await hydrateMissingUsersIfNeeded(for: displayedUsers)
        }
    }

    @MainActor
    private func loadMoreIfNeeded(currentUser: RepostBannerUser) async {
        guard currentUser.id == displayedUsers.last?.id else { return }
        guard let postId else { return }
        guard let cursor = nextCursor, !cursor.isEmpty else { return }
        guard !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await feedService.fetchReposters(postId: postId, limit: 20, cursor: cursor)
            displayedUsers = Self.dedupe(displayedUsers + page.items)
            nextCursor = page.nextCursor
            await hydrateMissingUsersIfNeeded(for: page.items)
        } catch {
            nextCursor = nil
        }
    }

    private static func dedupe(_ users: [RepostBannerUser]) -> [RepostBannerUser] {
        var seen = Set<Int>()
        var output: [RepostBannerUser] = []
        output.reserveCapacity(users.count)
        for user in users {
            if seen.insert(user.userId).inserted {
                output.append(user)
            }
        }
        return output
    }

    @MainActor
    private func hydrateMissingUsersIfNeeded(for users: [RepostBannerUser]) async {
        let candidates = users.filter { user in
            nonEmpty(user.profileImageURL) == nil
            && fallbackUsers[user.userId] == nil
            && attemptedFallbackUserIds.contains(user.userId) == false
        }

        for user in candidates {
            attemptedFallbackUserIds.insert(user.userId)
            do {
                let fetched = try await userService.getUser(by: user.userId)
                fallbackUsers[user.userId] = fetched
            } catch {
                // Keep default avatar when profile lookup fails.
            }
        }
    }
}
