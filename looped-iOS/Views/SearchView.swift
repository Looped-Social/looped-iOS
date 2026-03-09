import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showSearchResults = false
    @State private var selectedFieldsPageIndex = 0
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames
    @EnvironmentObject private var commentsManager: CommentsModalManager
    @State private var openingTrendingPostId: Int?
    @State private var trendingOpenError: String?

    private let feedService: FeedServiceProtocol = FeedService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Search Bar - Tappable to show search results
                    Button(action: {
                        showSearchResults = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.loopedTextSecondary)
                                .font(.loopedCustom(size: 16))
                            Text("Search Looped")
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.loopedGray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .coachMarkTarget(.searchPageSearchBar)
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 24) {
                        // Trending Post Section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Trending Posts")
                                    .font(.loopedSubheadSemibold)
                                    .foregroundColor(.loopedTextPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            if viewModel.isLoadingTrendingPosts && viewModel.trendingPosts.isEmpty {
                                TrendingPostsLoadingSkeletonRow()
                                    .transition(.opacity)
                            } else if viewModel.trendingPosts.isEmpty {
                                Text("No trending posts yet.")
                                    .font(.loopedSubBodyRegular)
                                    .foregroundColor(.loopedTextSecondary)
                                    .padding(.horizontal, 16)
                                    .transition(.opacity)
                            } else {
                                VStack(spacing: 6) {
                                    // Snap-to-center trending posts with TabView
                                    TabView(selection: $viewModel.selectedTrendingIndex) {
                                        ForEach(Array(viewModel.trendingPosts.enumerated()), id: \.element.id) { index, post in
                                            TrendingPostCard(
                                                imageName: post.imageURL ?? "",
                                                title: post.title,
                                                contentPreview: trendingPreviewText(for: post),
                                                authorName: trendingAuthorName(for: post),
                                                authorImageURL: post.authorProfileImageURL,
                                                isAnonymousAuthor: post.isAnonymous,
                                                postedInText: trendingCommunityText(for: post)
                                            )
                                            .overlay {
                                                if openingTrendingPostId == post.id {
                                                    ZStack {
                                                        Color.loopedBlack.opacity(0.25)
                                                        ProgressView()
                                                            .tint(.loopedWhite.opacity(0.92))
                                                    }
                                                }
                                            }
                                            .contentShape(Rectangle())
                                            .simultaneousGesture(TapGesture().onEnded {
                                                openTrendingPost(postId: post.id)
                                            })
                                            .padding(.horizontal, 16)
                                            .tag(index)
                                        }
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 290)

                                    if viewModel.trendingPosts.count > 1 {
                                        let totalPages = viewModel.trendingPosts.count
                                        let start = trendingPageIndicatorStartIndex(
                                            totalPages: totalPages,
                                            selectedPage: viewModel.selectedTrendingIndex
                                        )

                                        // Custom page indicator dots positioned lower
                                        HStack(spacing: 8) {
                                            ForEach(0..<trendingPageIndicatorDots, id: \.self) { offset in
                                                trendingPageIndicatorDot(
                                                    pageIndex: start + offset,
                                                    totalPages: totalPages,
                                                    selectedPage: viewModel.selectedTrendingIndex
                                                )
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.22), value: viewModel.isLoadingTrendingPosts)
                        .animation(.easeInOut(duration: 0.22), value: viewModel.trendingPosts.count)

                        Group {
                            let visiblePeopleRecommendationRails = viewModel.peopleRecommendationRails.filter {
                                $0.rail == .pymk && !$0.items.isEmpty
                            }

                            if viewModel.isLoadingPeopleRecommendations && viewModel.peopleRecommendationRails.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("People for You")
                                        .font(.loopedSubheadSemibold)
                                        .foregroundColor(.loopedTextPrimary)
                                        .padding(.horizontal, 16)
                                    PeopleRecommendationsLoadingSkeletonRow()
                                }
                                .transition(.opacity)
                            } else if !visiblePeopleRecommendationRails.isEmpty {
                                ForEach(visiblePeopleRecommendationRails, id: \.rail) { rail in
                                    PeopleRecommendationRailSection(
                                        rail: rail,
                                        isLoadingMore: viewModel.isLoadingMoreRecommendations(for: rail.rail),
                                        canConnect: { item in
                                            viewModel.canConnect(to: item)
                                        },
                                        isFollowing: { item in
                                            viewModel.isFollowingRecommendationUser(item.user.id)
                                        },
                                        isConnecting: { userId in
                                            viewModel.isConnectingRecommendationUser(userId)
                                        },
                                        onProfileTap: { item in
                                            viewModel.didTapRecommendationProfile(item)
                                        },
                                        onConnectTap: { item in
                                            Task { await viewModel.connectRecommendedUser(item) }
                                        },
                                        onHideTap: { item in
                                            viewModel.hideRecommendation(item)
                                        },
                                        onLessLikeThisTap: { item in
                                            viewModel.lessLikeThisRecommendation(item)
                                        },
                                        onItemAppear: { item in
                                            viewModel.didAppearRecommendation(item)
                                            if item.recommendationId == rail.items.last?.recommendationId {
                                                Task { await viewModel.loadMorePeopleRecommendations(for: rail.rail) }
                                            }
                                        },
                                        onItemDisappear: { item in
                                            viewModel.didDisappearRecommendation(item)
                                        }
                                    )
                                }
                                .transition(.opacity)
                            } else if viewModel.recommendationError != nil {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("People for You")
                                        .font(.loopedSubheadSemibold)
                                        .foregroundColor(.loopedTextPrimary)
                                    Text("Recommendations are unavailable right now.")
                                        .font(.loopedSubBodyRegular)
                                        .foregroundColor(.loopedTextSecondary)
                                }
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                            } else {
                                let emptyRecommendationMessage = viewModel.peopleRecommendationRails.isEmpty
                                    ? "Recommendations are currently unavailable."
                                    : "No recommendations yet."
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("People for You")
                                        .font(.loopedSubheadSemibold)
                                        .foregroundColor(.loopedTextPrimary)
                                    Text(emptyRecommendationMessage)
                                        .font(.loopedSubBodyRegular)
                                        .foregroundColor(.loopedTextSecondary)
                                }
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.22), value: viewModel.isLoadingPeopleRecommendations)
                        .animation(.easeInOut(duration: 0.22), value: viewModel.peopleRecommendationRails.count)

                        // Communities Section
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Communities")
                                    .font(.loopedSubheadSemibold)
                                    .foregroundColor(.loopedTextPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            Text("Recommended communities for you")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.recommendedCommunities) { community in
                                        NavigationLink(
                                            destination: CommunityProfileView(
                                                community: CommunityProfileData(community: community)
                                            )
                                        ) {
                                            LoopCard(
                                                title: CommunityLabelText.preferredName(
                                                    preferShortNames: preferCommunityShortNames,
                                                    name: community.name,
                                                    shortName: community.shortName
                                                ) ?? community.name,
                                                description: community.description,
                                                memberCount: community.memberCount,
                                                imageURL: community.bannerDisplayImageUrl,
                                                icon: community.icon,
                                                iconImageUrl: community.iconImageUrl,
                                                kind: community.kind,
                                                specializationType: community.specializationType
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .onAppear {
                                            if community.id == viewModel.recommendedCommunities.last?.id {
                                                Task { await viewModel.loadMoreRecommendedCommunities() }
                                            }
                                        }
                                    }

                                    if viewModel.isLoadingMoreRecommendedCommunities {
                                        LoadingLoopCard()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }

                        // Fields Section
                        fieldsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                if viewModel.trendingPosts.isEmpty {
                    Task { await viewModel.loadTrendingPosts() }
                }
                let hasVisibleRecommendationItems = viewModel.peopleRecommendationRails.contains { !$0.items.isEmpty }
                let shouldForceRefresh = viewModel.recommendationError != nil || !hasVisibleRecommendationItems
                Task { await viewModel.loadPeopleRecommendations(force: shouldForceRefresh) }
            }
        }
        .fullScreenCover(isPresented: $showSearchResults) {
            SearchResultsView()
                .environmentObject(commentsManager)
        }
        .alert(
            "Couldn't open post",
            isPresented: Binding(
                get: { trendingOpenError != nil },
                set: { if !$0 { trendingOpenError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(trendingOpenError ?? "Unknown error")
        }
    }

    private var fieldsSection: some View {
        let emptyMessage: String = {
            if viewModel.isLoadingSpecializations { return "Loading fields..." }
            return viewModel.specializationsError ?? "No fields yet."
        }()

        return SpecializationPagerSection(
            title: "Fields",
            items: viewModel.fields,
            emptyMessage: emptyMessage,
            selectedPageIndex: $selectedFieldsPageIndex,
            hasMorePages: viewModel.fieldsHasMorePages,
            isLoadingMore: viewModel.isLoadingMoreFields,
            onReachedEnd: { Task { await viewModel.loadMoreFields() } }
        )
    }

    private func trendingAuthorName(for post: TrendingPost) -> String {
        let trimmed = post.authorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return post.isAnonymous ? "Anonymous" : "Looped User"
    }

    private func trendingCommunityText(for post: TrendingPost) -> String {
        if let label = CommunityLabelText.preferredName(
            preferShortNames: preferCommunityShortNames,
            name: post.communityName,
            shortName: post.communityShortName
        ) {
            return "Posted in \(label)"
        }
        if let kind = post.communityKind?.trimmingCharacters(in: .whitespacesAndNewlines), !kind.isEmpty {
            return "Posted in \(kind.capitalized)"
        }
        return "Posted on Looped"
    }

    private func trendingPreviewText(for post: TrendingPost) -> String {
        let preview = post.contentPreview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !preview.isEmpty { return preview }
        return post.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trendingPageIndicatorDots: Int { 5 }

    private func trendingPageIndicatorStartIndex(totalPages: Int, selectedPage: Int) -> Int {
        let halfWindow = trendingPageIndicatorDots / 2
        var start = max(selectedPage - halfWindow, 0)
        start = min(start, max(totalPages - trendingPageIndicatorDots, 0))
        return start
    }

    @ViewBuilder
    private func trendingPageIndicatorDot(pageIndex: Int, totalPages: Int, selectedPage: Int) -> some View {
        let dotSize: CGFloat = 8
        let isActive = pageIndex == selectedPage
        let isLoadedPage = pageIndex >= 0 && pageIndex < totalPages

        if isActive {
            Circle()
                .fill(Color.loopedTextSecondary)
                .frame(width: dotSize, height: dotSize)
        } else if isLoadedPage {
            Circle()
                .fill(Color.loopedTextSecondary.opacity(0.3))
                .frame(width: dotSize, height: dotSize)
        } else {
            Circle()
                .stroke(Color.loopedTextSecondary.opacity(0.22), lineWidth: 1)
                .frame(width: dotSize, height: dotSize)
        }
    }

    private func openTrendingPost(postId: Int) {
        guard openingTrendingPostId == nil else { return }
        openingTrendingPostId = postId
        trendingOpenError = nil

        Task { @MainActor in
            defer { openingTrendingPostId = nil }
            do {
                let post = try await feedService.fetchPost(postId: postId)
                commentsManager.showComments(for: post, telemetryEntryPoint: "search_trending")
            } catch {
                trendingOpenError = error.localizedDescription
            }
        }
    }
}

private struct TrendingPostsLoadingSkeletonRow: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    TrendingPostLoadingSkeletonCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

private struct TrendingPostLoadingSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.loopedTextSecondary.opacity(0.16))
                .frame(height: 150)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.loopedTextSecondary.opacity(0.18))
                .frame(height: 14)
                .frame(maxWidth: .infinity)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.loopedTextSecondary.opacity(0.14))
                .frame(height: 12)
                .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.loopedTextSecondary.opacity(0.18))
                    .frame(width: 20, height: 20)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.loopedTextSecondary.opacity(0.12))
                    .frame(height: 12)
            }
        }
        .padding(12)
        .frame(width: 320, height: 290)
        .background(Color.loopedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PeopleRecommendationsLoadingSkeletonRow: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    PeopleRecommendationLoadingSkeletonCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct PeopleRecommendationLoadingSkeletonCard: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Circle()
                    .fill(Color.loopedTextSecondary.opacity(0.18))
                    .frame(width: 24, height: 24)
            }

            Circle()
                .fill(Color.loopedTextSecondary.opacity(0.16))
                .frame(width: 70, height: 70)
                .padding(.top, 4)
                .padding(.bottom, 10)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.loopedTextSecondary.opacity(0.18))
                .frame(height: 14)
                .padding(.horizontal, 10)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.loopedTextSecondary.opacity(0.14))
                .frame(height: 12)
                .padding(.top, 6)
                .padding(.horizontal, 24)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.loopedTextSecondary.opacity(0.12))
                .frame(height: 11)
                .padding(.top, 8)
                .padding(.horizontal, 14)

            Spacer(minLength: 0)

            Capsule()
                .fill(Color.loopedTextSecondary.opacity(0.16))
                .frame(height: 44)
                .padding(.bottom, 2)
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(width: 160, height: 248)
        .background(Color.loopedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct LoadingLoopCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.loopedMutedBackground.opacity(0.12))
                .frame(height: 64)
                .overlay {
                    ProgressView()
                        .tint(.loopedTextSecondary)
                }

            Text("Loading…")
                .font(.loopedSmallText)
                .foregroundColor(.loopedTextSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 140)
        .background(Color.loopedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color.loopedWhite.opacity(colorScheme == .dark ? 0.22 : 0.78),
                    lineWidth: 0.85
                )
                .blendMode(.overlay)
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.12 : 0.06),
            radius: colorScheme == .dark ? 7 : 4,
            x: 0,
            y: colorScheme == .dark ? 4 : 2
        )
        .shadow(
            color: Color.loopedBlack.opacity(colorScheme == .dark ? 0.05 : 0.025),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

private struct SpecializationPagerSection: View {
    private let columnsCount = 4
    private let gridSpacing: CGFloat = 16
    private let tileHeight: CGFloat = 128
    private let gridTopPadding: CGFloat = 8

    let title: String
    let items: [CommunitySearchResult]
    let emptyMessage: String
    @Binding var selectedPageIndex: Int
    let hasMorePages: Bool
    let isLoadingMore: Bool
    let onReachedEnd: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
    private let pageSize = 8
    private let pageIndicatorDots = 5

    var body: some View {
        let pages = chunked(items, size: pageSize)
        let pageCount = pages.count
        let maxRows = max(
            pages.map { max(1, Int(ceil(Double($0.count) / Double(columnsCount)))) }.max() ?? 1,
            1
        )
        let pageHeight = gridTopPadding + (CGFloat(maxRows) * tileHeight) + (CGFloat(maxRows - 1) * gridSpacing)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.loopedSubheadSemibold)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                if isLoadingMore {
                    ProgressView()
                        .tint(.loopedTextSecondary)
                }
            }
            .padding(.horizontal, 16)

            if items.isEmpty {
                Text(emptyMessage)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.horizontal, 16)
            } else {
                TabView(selection: $selectedPageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, pageItems in
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(pageItems) { specialization in
                                NavigationLink(
                                    destination: CommunityProfileView(
                                        community: CommunityProfileData(community: specialization)
                                    )
                                ) {
                                    SpecializationIcon(
                                        name: specialization.name,
                                        memberCount: specialization.memberCount,
                                        specializationType: specialization.specializationType,
                                        icon: specialization.icon,
                                        iconImageUrl: specialization.iconImageUrl
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, gridTopPadding)
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: pageHeight)
                .onChange(of: selectedPageIndex) { _, newValue in
                    guard pageCount > 0 else { return }
                    guard newValue >= pageCount - 1 else { return }
                    onReachedEnd()
                }

                if pageCount > 1 || hasMorePages {
                    let start = pageIndicatorStartIndex(
                        totalPages: pageCount,
                        selectedPage: selectedPageIndex,
                        hasMorePages: hasMorePages
                    )

                    HStack(spacing: 8) {
                        ForEach(0..<pageIndicatorDots, id: \.self) { offset in
                            pageIndicatorDot(
                                pageIndex: start + offset,
                                totalPages: pageCount,
                                selectedPage: selectedPageIndex,
                                hasMorePages: hasMorePages
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
        }
        .onChange(of: pageCount) { _, newValue in
            guard newValue > 0 else {
                selectedPageIndex = 0
                return
            }

            if selectedPageIndex >= newValue {
                selectedPageIndex = max(newValue - 1, 0)
            }
        }
    }

    private func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0, !items.isEmpty else { return [] }
        var result: [[T]] = []
        var index = 0
        while index < items.count {
            let end = min(index + size, items.count)
            result.append(Array(items[index..<end]))
            index = end
        }
        return result
    }

    private func pageIndicatorStartIndex(totalPages: Int, selectedPage: Int, hasMorePages: Bool) -> Int {
        let halfWindow = pageIndicatorDots / 2
        var start = max(selectedPage - halfWindow, 0)

        if hasMorePages == false {
            start = min(start, max(totalPages - pageIndicatorDots, 0))
        }

        return start
    }

    @ViewBuilder
    private func pageIndicatorDot(pageIndex: Int, totalPages: Int, selectedPage: Int, hasMorePages: Bool) -> some View {
        let dotSize: CGFloat = 8
        let isActive = pageIndex == selectedPage
        let isLoadedPage = pageIndex >= 0 && pageIndex < totalPages

        if isActive {
            Circle()
                .fill(Color.loopedTextSecondary)
                .frame(width: dotSize, height: dotSize)
        } else if isLoadedPage {
            Circle()
                .fill(Color.loopedTextSecondary.opacity(0.3))
                .frame(width: dotSize, height: dotSize)
        } else if hasMorePages {
            Circle()
                .fill(Color.loopedTextSecondary.opacity(0.18))
                .frame(width: dotSize, height: dotSize)
        } else {
            Circle()
                .stroke(Color.loopedTextSecondary.opacity(0.22), lineWidth: 1)
                .frame(width: dotSize, height: dotSize)
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(FeedViewModel())
        .environmentObject(CommentsModalManager())
        .environmentObject(AuthViewModel())
}
