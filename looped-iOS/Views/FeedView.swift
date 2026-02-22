import SwiftUI

struct FeedView: View {
    let onProfileTap: () -> Void
    @Binding private var isTabBarVisible: Bool
    @Binding private var scrollToTopSignal: Int
    @Environment(\.floatingActionButtonState) private var fabState
    @EnvironmentObject var viewModel: FeedViewModel
    @AppStorage("anonymousMode") private var isAnonymousMode = false
    @State private var headerVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isAtTop = true
    @State private var pollingTask: Task<Void, Never>?
    @State private var measuredHeaderHeight: CGFloat = 140
    @State private var activeImpressions: [String: ActiveFeedImpression] = [:]
    @State private var lockedActionSheetRequest: LockedActionSheetRequest?
    @State private var lockedActionCachedTabBarVisible: Bool?
    @State private var lockedActionCachedFabHidden: Bool?
    @State private var lastChromeToggleAt: TimeInterval = 0
    @State private var scrollDirectionTravel: CGFloat = 0
    @State private var activeNavigationDestination: FeedNavigationDestination?
    @State private var debugRawOffset: CGFloat = 0
    @State private var debugNormalizedOffset: CGFloat = 0
    @State private var debugDelta: CGFloat = 0
    @State private var debugSampleCount: Int = 0
    @State private var lastDebugConsoleBucket: Int = .min
    @State private var isUserActivelyScrolling = false
    @State private var scrollIdleWorkItem: DispatchWorkItem?

    private var headerHeight: CGFloat { max(0, measuredHeaderHeight) }
    private let pollInterval: TimeInterval = 90
    private let toastCooldown: TimeInterval = 7 * 60
    private let minNewPostsCount = 7
    private let topAnchorId = "feedTop"
    private var usesIOS17ScrollTuning: Bool {
        if #available(iOS 18.0, *) { return false }
        return true
    }
    private var uiTestDisableNetworkBootstrap: Bool {
        ProcessInfo.processInfo.environment["LOOPED_UI_TEST_DISABLE_NETWORK"] == "1"
    }
    private var showsScrollDebugOverlay: Bool {
        usesIOS17ScrollTuning && ProcessInfo.processInfo.environment["LOOPED_DEBUG_SCROLL"] == "1"
    }
    private var showsScrollDebugConsole: Bool {
        usesIOS17ScrollTuning && ProcessInfo.processInfo.environment["LOOPED_DEBUG_SCROLL_LOG"] == "1"
    }

    init(
        isTabBarVisible: Binding<Bool> = .constant(true),
        scrollToTopSignal: Binding<Int> = .constant(0),
        onProfileTap: @escaping () -> Void = {}
    ) {
        self._isTabBarVisible = isTabBarVisible
        self._scrollToTopSignal = scrollToTopSignal
        self.onProfileTap = onProfileTap
    }

    var body: some View {
        ZStack(alignment: .top) {

            // Simple native ScrollView with ScrollViewReader
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.loopedClear
                            .frame(height: 0)
                            .id(topAnchorId)
                            .background(
                                LoopedScrollOffsetObserver { offset in
                                    handleRawScroll(offset)
                                }
                            )

                        if usesIOS17ScrollTuning {
                            Color.loopedClear
                                .frame(height: headerHeight)
                                .allowsHitTesting(false)
                        }

                        LazyVStack(spacing: 0) {
                            if viewModel.isLoading && viewModel.posts.isEmpty {
                                if viewModel.showSkeleton {
                                    ForEach(0..<6, id: \.self) { index in
                                        PostCardSkeleton(showsMedia: index % 3 != 0)

                                        Rectangle()
                                            .frame(height: 1)
                                            .foregroundColor(.loopedTextSecondary.opacity(0.1))
                                    }
                                } else {
                                    ProgressView()
                                        .tint(.loopedPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 26)
                                }
                            } else if viewModel.posts.isEmpty {
                                EmptyFeedView()
                            } else {
                                ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                                    let telemetryContext = viewModel.feedTelemetryContext(for: post, position: index)
                                    PostCard(
                                        post: post,
                                        showsCommunityLabel: true,
                                        showsRepostBanner: true,
                                        telemetryFeedContext: telemetryContext,
                                        telemetryEntryPoint: "feed",
                                        onUpdate: { updated in
                                            viewModel.updatePost(updated)
                                        },
                                        onDelete: { deleted in
                                            viewModel.removePost(backendId: deleted.backendId)
                                        },
                                        onBlockUser: { blockedUserId in
                                            viewModel.removePosts(authorBackendId: blockedUserId)
                                        },
                                        onBlockPrincipal: { principalId in
                                            viewModel.removePosts(authorPrincipalId: principalId)
                                        },
                                        onPresentLockedActionSheet: { request in
                                            lockedActionSheetRequest = request
                                            prepareForLockedActionPresentation()
                                        },
                                        onAuthorNavigationRequested: { profileId, isAnonymousProfile in
                                            handleAuthorNavigationRequest(profileId: profileId, isAnonymousProfile: isAnonymousProfile)
                                        },
                                        onCommunityNavigationRequested: { community in
                                            handleCommunityNavigationRequest(community)
                                        }
                                    )
                                        .onAppear {
                                            beginImpressionTracking(for: post, context: telemetryContext)
                                            Task {
                                                await viewModel.loadMoreIfNeeded(currentPost: post)
                                            }
                                        }
                                        .onDisappear {
                                            endImpressionTracking(for: post)
                                        }

                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
                                }

                                if viewModel.isLoadingMore {
                                    LoopedInlineLoadingIndicator()
                                }
                            }
                        }
                    }
                }
                .onChange(of: scrollToTopSignal) { _, _ in
                    scrollToTop(proxy: proxy)
                }
                .feedTopSafeInsetIfNeeded(height: headerHeight, isEnabled: !usesIOS17ScrollTuning)
                .loopedPullToRefresh(
                    isEnabled: !viewModel.isCommunitySearchActive && !usesIOS17ScrollTuning,
                    isAtTop: isAtTop,
                    indicatorTopPadding: headerVisible ? headerHeight + 14 : 16
                ) {
                    setChromeVisibility(true, force: true)
                    await viewModel.loadInitial()
                }
                .overlay(alignment: .top) {
                    if let count = viewModel.newPostsToastCount {
                        FeedNewPostsToast(
                            count: count,
                            onTap: {
                                handleToastTap(proxy: proxy)
                            },
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.dismissNewPostsToast()
                                }
                            }
                        )
                        .padding(.top, headerVisible ? headerHeight + 12 : 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.newPostsToastCount)
            }
            .overlay(alignment: .bottom) {
                if viewModel.isLoadingMore && !viewModel.posts.isEmpty {
                    LoopedInlineLoadingIndicator()
                        .background(Color.loopedBackground.opacity(0.92))
                        .padding(.bottom, isTabBarVisible ? 72 : 12)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }

            // Fixed header with proper safe area handling
            VStack(spacing: 0) {
                FeedHeader(onProfileTap: onProfileTap)
                FeedTabs(
                    isSearching: $viewModel.isCommunitySearchActive,
                    searchQuery: $viewModel.communitySearchQuery,
                    communities: viewModel.feedFilterCommunities,
                    selectedCommunityId: viewModel.selectedCommunity?.id,
                    onSelectCommunity: { community in
                        Task { await viewModel.selectCommunity(community) }
                    },
                    onSelectAll: {
                        Task { await viewModel.selectAllCommunities() }
                    },
                    onLoadMore: { community in
                        Task { await viewModel.loadMoreFollowedCommunitiesIfNeeded(currentCommunity: community) }
                    },
                    onSelectMode: { mode in
                        Task { await viewModel.selectFeedMode(mode) }
                    },
                    searchResults: viewModel.communitySearchResults,
                    isSearchLoading: viewModel.isCommunitySearchLoading,
                    searchErrorMessage: viewModel.communitySearchError,
                    onSearchQueryChange: { query in
                        viewModel.updateCommunitySearchQuery(query)
                    },
                    onSelectSearchResult: { result in
                        Task { await viewModel.selectCommunityFromSearchResult(result) }
                    },
                    onDismissSearch: {
                        viewModel.dismissCommunitySearch()
                    }
                )
            }
            .background(
                GeometryReader { proxy in
                    Color.loopedClear
                        .preference(key: FeedHeaderHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .background(
                Color.loopedBackground
                    .ignoresSafeArea(.all, edges: .top)
                    .allowsHitTesting(false)
            )
            .offset(y: headerVisible ? 0 : -headerHeight)
            .opacity(headerVisible ? 1 : 0)
            .allowsHitTesting(headerVisible)
        }
        .background(Color.loopedBackground)
        .navigationBarHidden(true)
        .overlay(alignment: .bottomLeading) {
            if showsScrollDebugOverlay {
                scrollDebugOverlay
                    .padding(.leading, 12)
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
        }
        .navigationDestination(item: $activeNavigationDestination) { destination in
            switch destination {
            case .userProfile(let userId):
                UserProfileView(userId: userId)
            case .anonymousProfile(let profileId):
                UserProfileView(anonProfileId: profileId)
            case .community(let community):
                CommunityProfileView(community: community)
            }
        }
        .overlay {
            LoopedBottomDrawer(
                isPresented: lockedActionSheetRequest != nil,
                onDismiss: { dismissLockedActionSheet(triggerSecondary: true) }
            ) {
                if let request = lockedActionSheetRequest {
                    LockedActionSheet(
                        reason: request.reason,
                        actionType: request.actionType,
                        isPrimaryLoading: false,
                        onPrimary: {
                            dismissLockedActionSheet(triggerSecondary: false)
                            request.onPrimary()
                        },
                        onHowItWorks: request.onHowItWorks == nil ? nil : {
                            dismissLockedActionSheet(triggerSecondary: false)
                            request.onHowItWorks?()
                        }
                    )
                }
            }
        }
        .onPreferenceChange(FeedHeaderHeightPreferenceKey.self) { newValue in
            guard newValue > 0 else { return }
            if abs(newValue - measuredHeaderHeight) > 0.5 {
                measuredHeaderHeight = newValue
            }
        }
        .task {
            guard !uiTestDisableNetworkBootstrap else { return }
            await viewModel.loadInitial()
        }
        .onAppear {
            fabState.isHidden = false
            headerVisible = true
            isTabBarVisible = true
            lastScrollOffset = 0
            scrollDirectionTravel = 0
            isUserActivelyScrolling = false
            scrollIdleWorkItem?.cancel()
            scrollIdleWorkItem = nil
            lastChromeToggleAt = Date().timeIntervalSince1970
            if showsScrollDebugConsole {
                print("[FeedScroll] debug console enabled")
            }
            startPolling()
        }
        .onDisappear {
            flushActiveImpressions()
            withAnimation(.easeInOut(duration: 0.2)) {
                isTabBarVisible = true
            }
            // If the view disappears while the locked drawer is up, restore global UI state.
            if lockedActionSheetRequest != nil, let cachedFabHidden = lockedActionCachedFabHidden {
                fabState.isHidden = cachedFabHidden
                lockedActionCachedTabBarVisible = nil
                lockedActionCachedFabHidden = nil
                lockedActionSheetRequest = nil
            }
            scrollIdleWorkItem?.cancel()
            scrollIdleWorkItem = nil
            isUserActivelyScrolling = false
            stopPolling()
        }
        .onChange(of: isAnonymousMode) { _, _ in
            Task {
                await viewModel.loadPosts(reset: true, clearExistingPosts: true, force: true)
            }
        }
        .loopedHashtagNavigationHost()
        .loopedMentionNavigationHost()
        .accessibilityIdentifier("feed.screen")
    }

    private func prepareForLockedActionPresentation() {
        if lockedActionCachedTabBarVisible == nil {
            lockedActionCachedTabBarVisible = isTabBarVisible
            lockedActionCachedFabHidden = fabState.isHidden
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isTabBarVisible = false
        }
        fabState.isHidden = true
    }

    private func restoreAfterLockedActionPresentation() {
        if let cached = lockedActionCachedTabBarVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                isTabBarVisible = cached
            }
        }
        if let cachedFabHidden = lockedActionCachedFabHidden {
            fabState.isHidden = cachedFabHidden
        }
        lockedActionCachedTabBarVisible = nil
        lockedActionCachedFabHidden = nil
    }

    private func dismissLockedActionSheet(triggerSecondary: Bool) {
        guard let request = lockedActionSheetRequest else { return }
        lockedActionSheetRequest = nil
        restoreAfterLockedActionPresentation()
        if triggerSecondary {
            request.onSecondary()
        }
    }

    private func handleAuthorNavigationRequest(profileId: Int, isAnonymousProfile: Bool) {
        activeNavigationDestination = isAnonymousProfile
            ? .anonymousProfile(profileId: profileId)
            : .userProfile(userId: profileId)
    }

    private func handleCommunityNavigationRequest(_ community: CommunityProfileData) {
        activeNavigationDestination = .community(community: community)
    }

    private func handleRawScroll(_ rawOffset: CGFloat) {
        if showsScrollDebugOverlay {
            debugRawOffset = rawOffset
            debugNormalizedOffset = rawOffset
            debugSampleCount = (debugSampleCount + 1) % 100_000
        }
        handleScroll(rawOffset)
        if showsScrollDebugConsole {
            let bucket = Int((rawOffset / 16).rounded(.towardZero))
            if bucket != lastDebugConsoleBucket {
                lastDebugConsoleBucket = bucket
                print("[FeedScroll] raw=\(Int(rawOffset)) off=\(Int(debugNormalizedOffset)) delta=\(Int(debugDelta)) travel=\(Int(scrollDirectionTravel)) header=\(headerVisible) top=\(isAtTop)")
            }
        }
    }

    private func handleScroll(_ offset: CGFloat) {
        guard lockedActionSheetRequest == nil else { return }

        let topStateThreshold: CGFloat = usesIOS17ScrollTuning ? -24 : -50
        let minimumDirectionalDelta: CGFloat = usesIOS17ScrollTuning ? 1.0 : 0.8
        let delta = offset - lastScrollOffset
        markUserScrollingIfNeeded(delta: delta)
        if showsScrollDebugOverlay || showsScrollDebugConsole {
            debugNormalizedOffset = offset
            debugDelta = delta
        }
        let maxReasonableDelta: CGFloat = usesIOS17ScrollTuning ? 120 : 180
        if abs(delta) > maxReasonableDelta {
            // Ignore sudden geometry jumps caused by layout transitions.
            scrollDirectionTravel = 0
            lastScrollOffset = offset
            return
        }
        if abs(delta) < minimumDirectionalDelta {
            let atTop = offset >= topStateThreshold
            if atTop != isAtTop {
                isAtTop = atTop
            }
            lastScrollOffset = offset
            return
        }

        if viewModel.isCommunitySearchActive {
            setChromeVisibility(true, force: true)
            scrollDirectionTravel = 0
            lastScrollOffset = offset
            let atTop = offset >= topStateThreshold
            if atTop != isAtTop {
                isAtTop = atTop
            }
            return
        }

        if usesIOS17ScrollTuning {
            let nearTopThreshold: CGFloat = -24
            let hideTriggerOffset: CGFloat = -96
            let hideTravelThreshold: CGFloat = 24

            if delta < 0 {
                scrollDirectionTravel = min(0, scrollDirectionTravel) + delta
            } else if delta > 0 {
                scrollDirectionTravel = max(0, scrollDirectionTravel) + delta
            }

            if offset >= nearTopThreshold {
                scrollDirectionTravel = 0
                setChromeVisibility(true, force: true)
            } else if scrollDirectionTravel <= -hideTravelThreshold, offset <= hideTriggerOffset {
                scrollDirectionTravel = 0
                setChromeVisibility(false)
            }

            let atTop = offset >= nearTopThreshold
            if atTop != isAtTop {
                isAtTop = atTop
            }
            lastScrollOffset = offset
            return
        }

        let nearTopThreshold: CGFloat = -50
        let hideTriggerOffset: CGFloat = -110
        let hideTravelThreshold: CGFloat = 22
        let showTravelThreshold: CGFloat = 18

        if delta < 0 {
            scrollDirectionTravel = min(0, scrollDirectionTravel) + delta
        } else if delta > 0 {
            scrollDirectionTravel = max(0, scrollDirectionTravel) + delta
        }

        var updatedVisibility: Bool?

        // Always show chrome near the top boundary.
        if offset >= nearTopThreshold {
            scrollDirectionTravel = 0
            updatedVisibility = true
        }
        // Hide when downward travel accumulates below the trigger offset.
        else if scrollDirectionTravel <= -hideTravelThreshold, offset <= hideTriggerOffset {
            scrollDirectionTravel = 0
            updatedVisibility = false
        }
        // Show when upward travel accumulates.
        else if scrollDirectionTravel >= showTravelThreshold {
            scrollDirectionTravel = 0
            updatedVisibility = true
        }

        if let updatedVisibility {
            setChromeVisibility(updatedVisibility, force: offset >= nearTopThreshold)
        }

        let atTop = offset >= nearTopThreshold
        if atTop != isAtTop {
            isAtTop = atTop
        }
        lastScrollOffset = offset
    }

    @ViewBuilder
    private var scrollDebugOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("raw: \(Int(debugRawOffset))")
            Text("off: \(Int(debugNormalizedOffset))")
            Text("delta: \(Int(debugDelta))")
            Text("samples: \(debugSampleCount)")
            Text("travel: \(Int(scrollDirectionTravel))")
            Text("header: \(headerVisible ? "1" : "0")")
            Text("tab: \(isTabBarVisible ? "1" : "0")")
            Text("top: \(isAtTop ? "1" : "0")")
            Text("scrolling: \(isUserActivelyScrolling ? "1" : "0")")
        }
        .font(.loopedSmallText)
        .foregroundColor(.loopedBackground)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.loopedTextPrimary.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func setChromeVisibility(_ isVisible: Bool, force: Bool = false) {
        let targetTabBarVisible = isVisible
        guard headerVisible != isVisible || isTabBarVisible != targetTabBarVisible else { return }

        let now = Date().timeIntervalSince1970
        let toggleCooldown: TimeInterval = 0.16
        if !force, now - lastChromeToggleAt < toggleCooldown {
            return
        }

        lastChromeToggleAt = now
        withAnimation(.easeInOut(duration: 0.22)) {
            headerVisible = isVisible
            isTabBarVisible = targetTabBarVisible
        }
        if showsScrollDebugConsole {
            print("[FeedChrome] header=\(isVisible) tab=\(targetTabBarVisible) force=\(force)")
        }
    }

    private func markUserScrollingIfNeeded(delta: CGFloat) {
        if abs(delta) <= 0.15 {
            return
        }

        if !isUserActivelyScrolling {
            isUserActivelyScrolling = true
        }

        scrollIdleWorkItem?.cancel()
        let work = DispatchWorkItem {
            isUserActivelyScrolling = false
        }
        scrollIdleWorkItem = work
        let idleDelay: TimeInterval = usesIOS17ScrollTuning ? 0.16 : 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + idleDelay, execute: work)
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                let delay = UInt64(pollInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                await viewModel.checkForNewPosts(
                    minCount: minNewPostsCount,
                    cooldown: toastCooldown,
                    isAtTop: isAtTop
                )
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func beginImpressionTracking(for post: Post, context: TelemetryFeedContext) {
        guard let postId = post.backendId else { return }
        let key = impressionKey(postId: postId)
        guard activeImpressions[key] == nil else { return }
        activeImpressions[key] = ActiveFeedImpression(
            postId: postId,
            feedContext: context,
            startMs: TelemetryClock.nowMs,
            canInteract: post.viewerCapabilities?.canInteract,
            lockReason: post.viewerCapabilities?.lockReason?.rawValue
        )
    }

    private func endImpressionTracking(for post: Post) {
        guard let postId = post.backendId else { return }
        let key = impressionKey(postId: postId)
        guard let active = activeImpressions.removeValue(forKey: key) else { return }
        emitImpressionIfNeeded(from: active, endedAtMs: TelemetryClock.nowMs)
    }

    private func flushActiveImpressions() {
        let endedAt = TelemetryClock.nowMs
        let active = activeImpressions.values
        activeImpressions.removeAll(keepingCapacity: false)
        for impression in active {
            emitImpressionIfNeeded(from: impression, endedAtMs: endedAt)
        }
    }

    private func emitImpressionIfNeeded(from active: ActiveFeedImpression, endedAtMs: Int64) {
        let visibleMs = max(0, Int(endedAtMs - active.startMs))
        guard visibleMs >= 500 else { return }
        Task {
            await TelemetryManager.shared.trackFeedImpression(
                postId: active.postId,
                feed: active.feedContext,
                visibleMs: visibleMs,
                canInteract: active.canInteract,
                lockReason: active.lockReason
            )
        }
    }

    private func impressionKey(postId: Int) -> String {
        return "\(postId)"
    }

    private func handleToastTap(proxy: ScrollViewProxy) {
        viewModel.dismissNewPostsToast()
        Task {
            await viewModel.refreshPosts()
            scrollToTop(proxy: proxy)
        }
    }

    private func scrollToTop(proxy: ScrollViewProxy) {
        setChromeVisibility(true, force: true)

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(topAnchorId, anchor: .top)
            }
        }
    }
}

private struct ActiveFeedImpression {
    let postId: Int
    let feedContext: TelemetryFeedContext
    let startMs: Int64
    let canInteract: Bool?
    let lockReason: String?
}

private enum FeedNavigationDestination: Hashable, Identifiable {
    case userProfile(userId: Int)
    case anonymousProfile(profileId: Int)
    case community(community: CommunityProfileData)

    var id: String {
        switch self {
        case .userProfile(let userId):
            return "user-\(userId)"
        case .anonymousProfile(let profileId):
            return "anon-\(profileId)"
        case .community(let community):
            return "community-\(community.id)"
        }
    }

    static func == (lhs: FeedNavigationDestination, rhs: FeedNavigationDestination) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct FeedHeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 140

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

private extension View {
    @ViewBuilder
    func feedTopSafeInsetIfNeeded(height: CGFloat, isEnabled: Bool) -> some View {
        if isEnabled {
            self.safeAreaInset(edge: .top, spacing: 0) {
                Color.loopedClear
                    .frame(height: height)
                    .allowsHitTesting(false)
            }
        } else {
            self
        }
    }
}


#Preview {
    FeedView()
        .environmentObject(FeedViewModel())
        .environmentObject(AuthViewModel())
}
