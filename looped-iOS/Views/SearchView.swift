import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showSearchResults = false
    @State private var selectedMajorsPageIndex = 0
    @State private var selectedFieldsPageIndex = 0
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames
    @EnvironmentObject private var commentsManager: CommentsModalManager
    @EnvironmentObject private var feedViewModel: FeedViewModel
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
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 24) {
                        // Trending Post Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Trending Posts")
                                    .font(.loopedSubheadMedium)
                                    .foregroundColor(.loopedTextPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            if viewModel.trendingPosts.isEmpty {
                                Text("No trending posts yet.")
                                    .font(.loopedSubBodyRegular)
                                    .foregroundColor(.loopedTextSecondary)
                                    .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 12) {
                                    // Snap-to-center trending posts with TabView
                                    TabView(selection: $viewModel.selectedTrendingIndex) {
                                        ForEach(Array(viewModel.trendingPosts.enumerated()), id: \.element.id) { index, post in
                                            TrendingPostCard(
                                                imageName: post.imageURL ?? "",
                                                title: post.title,
                                                subtitle: post.subtitleText(preferShortNames: preferCommunityShortNames)
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
                                    .frame(height: 200)

                                    if viewModel.trendingPosts.count > 1 {
                                        // Custom page indicator dots positioned lower
                                        HStack(spacing: 8) {
                                            ForEach(0..<viewModel.trendingPosts.count, id: \.self) { index in
                                                Circle()
                                                    .fill(index == viewModel.selectedTrendingIndex ? Color.loopedTextSecondary : Color.loopedTextSecondary.opacity(0.3))
                                                    .frame(width: 8, height: 8)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }

                        // Communities Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Communities")
                                    .font(.loopedSubheadMedium)
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
                                                imageURL: community.imageUrl,
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
                            }
                        }

                        // Majors & Fields Section
                        VStack(alignment: .leading, spacing: 24) {
                            if shouldShowFieldsFirst {
                                fieldsSection
                                majorsSection
                            } else {
                                majorsSection
                                fieldsSection
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showSearchResults) {
            SearchResultsView()
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

    private var shouldShowFieldsFirst: Bool {
        let hasCompany = feedViewModel.followedCommunities.contains(where: { $0.kind == .company })
        let hasSchool = feedViewModel.followedCommunities.contains(where: { $0.kind == .school })

        if hasCompany && !hasSchool { return true }
        if hasSchool && !hasCompany { return false }
        return false
    }

    private var majorsSection: some View {
        let emptyMessage: String = {
            if viewModel.isLoadingSpecializations { return "Loading majors..." }
            return viewModel.specializationsError ?? "No majors yet."
        }()

        return SpecializationPagerSection(
            title: "Majors",
            items: viewModel.majors,
            emptyMessage: emptyMessage,
            selectedPageIndex: $selectedMajorsPageIndex,
            hasMorePages: viewModel.majorsHasMorePages,
            isLoadingMore: viewModel.isLoadingMoreMajors,
            onReachedEnd: { Task { await viewModel.loadMoreMajors() } }
        )
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

    private func openTrendingPost(postId: Int) {
        guard openingTrendingPostId == nil else { return }
        openingTrendingPostId = postId
        trendingOpenError = nil

        Task { @MainActor in
            defer { openingTrendingPostId = nil }
            do {
                let post = try await feedService.fetchPost(postId: postId)
                commentsManager.showComments(for: post)
            } catch {
                trendingOpenError = error.localizedDescription
            }
        }
    }
}

private struct LoadingLoopCard: View {
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.loopedMutedBackground, lineWidth: 1)
        )
    }
}

private struct SpecializationPagerSection: View {
    let title: String
    let items: [CommunitySearchResult]
    let emptyMessage: String
    @Binding var selectedPageIndex: Int
    let hasMorePages: Bool
    let isLoadingMore: Bool
    let onReachedEnd: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
    private let pageSize = 8
    private let pageHeight: CGFloat = 220
    private let pageIndicatorDots = 5

    var body: some View {
        let pages = chunked(items, size: pageSize)
        let pageCount = pages.count

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.loopedSubheadMedium)
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
                                        specializationType: specialization.specializationType
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
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
