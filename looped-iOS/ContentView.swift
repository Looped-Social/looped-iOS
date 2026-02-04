//
//  ContentView.swift
//  looped-iOS
//
//  Created by William Millen on 9/5/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif


enum MenuDestination: Identifiable {
    case posts
    case replies
    case liked
    case saved
    case drafts
    case analytics
    case faq
    case settings

    var id: String {
        switch self {
        case .posts: return "posts"
        case .replies: return "replies"
        case .liked: return "liked"
        case .saved: return "saved"
        case .drafts: return "drafts"
        case .analytics: return "analytics"
        case .faq: return "faq"
        case .settings: return "settings"
        }
    }
}

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var feedViewModel = FeedViewModel()
    @State private var keepBootstrapVisible = false
    @State private var showNotificationPermissionPrompt = false
    @AppStorage("showAccountDeletedAlert") private var showAccountDeletedAlert = false
    @AppStorage("showAccountDeactivatedAlert") private var showAccountDeactivatedAlert = false
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("preferCommunityShortNames") private var preferCommunityShortNames = true
    @AppStorage("defaultProfileImageUrl") private var defaultProfileImageUrl = ""
    @AppStorage("defaultProfileImageUrlFetchedAt") private var defaultProfileImageUrlFetchedAt = 0.0
    @AppStorage("didShowNotificationPermissionPrompt") private var didShowNotificationPermissionPrompt = false

    var body: some View {
        Group {
            if authViewModel.isAuthenticated, (!authViewModel.didLoadIdentity || keepBootstrapVisible) {
                LaunchBootstrapView(isReady: authViewModel.didLoadIdentity) {
                    keepBootstrapVisible = false
                }
                .onAppear {
                    keepBootstrapVisible = !authViewModel.didLoadIdentity
                }
            } else if authViewModel.isAuthenticated {
                if !authViewModel.onboardingComplete {
                    AuthView(authViewModel: authViewModel)
                } else {
                    MainTabView()
                }
            } else {
                AuthView(authViewModel: authViewModel)
            }
        }
        .task {
            await loadDefaultProfileImageIfNeeded()
        }
        .task(id: notificationPromptKey) {
            await evaluateNotificationPermissionPromptIfNeeded()
        }
        .fullScreenCover(isPresented: $showNotificationPermissionPrompt) {
            NotificationPermissionPromptView {
                didShowNotificationPermissionPrompt = true
                showNotificationPermissionPrompt = false
            }
        }
        .alert("Accounts Deleted", isPresented: $showAccountDeletedAlert) {
            Button("OK", role: .cancel) {
                showAccountDeletedAlert = false
            }
        } message: {
            Text("Your account and anonymous profile have been deleted.")
        }
        .alert("Account Deactivated", isPresented: $showAccountDeactivatedAlert) {
            Button("OK", role: .cancel) {
                showAccountDeactivatedAlert = false
            }
        } message: {
            Text("Your profile is hidden until you log back in.")
        }
        .environmentObject(authViewModel)
        .environmentObject(feedViewModel)
        .environment(\.preferCommunityShortNames, preferCommunityShortNames)
        .preferredColorScheme(preferredColorScheme)
        .onChange(of: preferCommunityShortNames) { _, _ in
            Task { await feedViewModel.loadFollowedCommunities(reset: true) }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        AppearanceMode.from(rawValue: appearanceMode).colorScheme
    }

    private var notificationPromptKey: String {
        [
            authViewModel.isAuthenticated ? "auth" : "noauth",
            authViewModel.didLoadIdentity ? "id" : "noid",
            authViewModel.onboardingComplete ? "onboarded" : "notonboarded",
            didShowNotificationPermissionPrompt ? "prompted" : "unprompted"
        ].joined(separator: "|")
    }

    private func evaluateNotificationPermissionPromptIfNeeded() async {
        guard authViewModel.isAuthenticated else { return }
        guard authViewModel.didLoadIdentity else { return }
        guard authViewModel.onboardingComplete else { return }
        guard !didShowNotificationPermissionPrompt else { return }
        guard !showNotificationPermissionPrompt else { return }

        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            await MainActor.run {
                showNotificationPermissionPrompt = true
            }
        case .authorized, .provisional, .ephemeral, .denied:
            await MainActor.run {
                didShowNotificationPermissionPrompt = true
            }
        @unknown default:
            await MainActor.run {
                didShowNotificationPermissionPrompt = true
            }
        }
        #else
        await MainActor.run {
            didShowNotificationPermissionPrompt = true
        }
        #endif
    }

    private func loadDefaultProfileImageIfNeeded() async {
        let now = Date().timeIntervalSince1970
        let refreshAfterSeconds = 24.0 * 60.0 * 60.0
        if now - defaultProfileImageUrlFetchedAt < refreshAfterSeconds, !defaultProfileImageUrl.isEmpty {
            return
        }

        do {
            let config = try await AppConfigService().fetch()
            defaultProfileImageUrl = (config.defaultProfileImageUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            defaultProfileImageUrlFetchedAt = now
        } catch {
            // Best-effort; the UI will still fall back to local placeholders.
        }
    }
}

private struct LaunchBootstrapView: View {
	    @Environment(\.accessibilityReduceMotion) private var reduceMotion
	    @State private var revealProgress: CGFloat = 0
	    @State private var didFinish = false
	    private static let baseLogoFrameDimension: CGFloat = 180
	    private static let launchScreenMatchScale: CGFloat = {
	        guard let launchLogo = UIImage(named: "LaunchLogo") else { return 1 }
	        guard let appLogo = UIImage(named: "logo") else { return 1 }

	        let launchAspect = launchLogo.size.width / max(launchLogo.size.height, 1)
	        let appAspect = appLogo.size.width / max(appLogo.size.height, 1)
	        guard launchAspect > 0, appAspect > 0 else { return 1 }

	        return appAspect / launchAspect
	    }()

	    let isReady: Bool
	    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.loopedBackground.ignoresSafeArea()

	            VStack(spacing: 18) {
	                animatedLogo
	                    .frame(width: logoFrameDimension, height: logoFrameDimension)
	                    .accessibilityHidden(true)
	            }
	            .padding(.horizontal, 24)
	        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .onAppear {
            didFinish = false

            if reduceMotion {
                revealProgress = isReady ? 1 : 0.9
                if isReady {
                    finishIfNeeded()
                }
                return
            }

            revealProgress = 0
            if isReady {
                withAnimation(.easeInOut(duration: 0.25)) {
                    revealProgress = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    finishIfNeeded()
                }
            } else {
                withAnimation(.easeOut(duration: 0.7)) {
                    revealProgress = 0.9
                }
            }
        }
        .onChange(of: isReady) { _, newValue in
            guard newValue else { return }
            if reduceMotion {
                revealProgress = 1
                finishIfNeeded()
                return
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                revealProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                finishIfNeeded()
            }
        }
    }

	    private var animatedLogo: some View {
	        ZStack {
	            Image("logo")
	                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(placeholderLogoColor)

            Image("logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.loopedPrimary)
                .mask(
                    GeometryReader { proxy in
                        Rectangle()
                            .frame(width: proxy.size.width * revealProgress, height: proxy.size.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                )
	        }
	        .compositingGroup()
	    }

	    private var logoFrameDimension: CGFloat {
	        Self.baseLogoFrameDimension * Self.launchScreenMatchScale
	    }

	    private var placeholderLogoColor: Color {
	        Color(.sRGB, red: 175.0 / 255.0, green: 162.0 / 255.0, blue: 162.0 / 255.0, opacity: 1)
	    }

    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }
}

struct MainTabView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var feedViewModel: FeedViewModel
    @State private var selectedTab: TabItem = .home
    @State private var homePopToRootSignal = 0
    @State private var homePopToRootProcessedSignal = 0
    @State private var homeDidPopOnReselect = false
    @State private var feedScrollToTopSignal = 0
    @State private var showCreatePost = false
    @State private var showNewMessage = false
    @State private var isRightMenuOpen = false
	    @State private var showingChat = false
	    @State private var selectedConversation: Conversation?
	    @State private var selectedChannel: Channel?
	    @State private var deepLinkConversationId: Int?
	    @State private var deepLinkChannelId: Int?
	    @State private var menuDestination: MenuDestination?
	    @State private var mainOverlayDestination: LoopedMainOverlayDestination?
	    @State private var tabBarHeight: CGFloat = 0
	    @State private var showFAQSheet = false
	    @State private var deepLinkProfile: DeepLinkProfile?
    @StateObject private var commentsManager = CommentsModalManager()
    @StateObject private var fabState = FloatingActionButtonState()
    @StateObject private var coachMarkPresenter = CoachMarkPresenter()
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    @StateObject private var messagesViewModel = MessagesViewModel()
    @State private var isTabBarVisible = true
    @AppStorage("anonymousMode") private var isAnonymousMode = false
    @AppStorage("lastSeenNotificationsAt") private var lastSeenNotificationsAt = 0.0
    @AppStorage("lastSeenMessagesAt") private var lastSeenMessagesAt = 0.0
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("didShowFeedDiscovery") private var didShowFeedDiscovery = false
    @State private var feedDiscoveryStep: FeedDiscoveryStep?
    @AppStorage("unverifiedSearchDiscoveryLastShownAt") private var unverifiedSearchDiscoveryLastShownAt = 0.0
    @AppStorage("unverifiedSearchDiscoveryParity") private var unverifiedSearchDiscoveryParity = 0
    @State private var isShowingUnverifiedSearchDiscovery = false
    @State private var didEvaluateUnverifiedSearchDiscoveryThisSession = false
    @State private var toastMessage: ToastMessage?
    private let faqUrl = URL(string: "https://www.mylooped.app/faq")!
    private let deepLinkFeedService: FeedServiceProtocol = FeedService()
    
    var body: some View {
        GeometryReader { geometry in
            mainLayout(for: geometry)
        }
        .environment(\.floatingActionButtonState, fabState)
        .task {
            didEvaluateUnverifiedSearchDiscoveryThisSession = false
            async let loadCommunities: Void = feedViewModel.loadFollowedCommunities()
            async let loadNotifications: Void = notificationsViewModel.loadNotifications()
            if !isAnonymousMode {
                async let loadInbox: Void = messagesViewModel.loadInbox()
                _ = await (loadCommunities, loadNotifications, loadInbox)
            } else {
                _ = await (loadCommunities, loadNotifications)
            }
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
        }
        .onAppear {
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
        }
        .onChange(of: selectedTab) { _, _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isTabBarVisible = true
            }
            updateLastSeen(for: selectedTab)
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
            syncFloatingActionButtonVisibility()
            if selectedTab == .home {
                VideoPlaybackManager.shared.requestVisibilityRefresh()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    VideoPlaybackManager.shared.requestVisibilityRefresh()
                }
            } else {
                VideoPlaybackManager.shared.resetVisibility()
            }
        }
        .onChange(of: homePopToRootProcessedSignal) { _, _ in
            guard selectedTab == .home else { return }
            guard homePopToRootProcessedSignal == homePopToRootSignal else { return }
            guard homeDidPopOnReselect == false else { return }
            feedScrollToTopSignal += 1
        }
        .onChange(of: isRightMenuOpen) { _, _ in
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
        }
        .onChange(of: commentsManager.isPresented) { _, _ in
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
        }
        .onChange(of: showingChat) { _, _ in
            startFeedDiscoveryIfNeeded()
            startUnverifiedSearchDiscoveryIfNeeded()
        }
        .onReceive(notificationsViewModel.$notifications) { _ in
            guard selectedTab == .notifications else { return }
            lastSeenNotificationsAt = Date().timeIntervalSince1970
        }
        .onReceive(messagesViewModel.$conversations) { _ in
            guard selectedTab == .messages else { return }
            lastSeenMessagesAt = Date().timeIntervalSince1970
        }
        .onReceive(messagesViewModel.$messageRequests) { _ in
            guard selectedTab == .messages else { return }
            lastSeenMessagesAt = Date().timeIntervalSince1970
        }
        .environmentObject(feedViewModel)
        .environmentObject(commentsManager)
        .toast($toastMessage)
	        .overlay(
	            Group {
	                if commentsManager.isPresented, let post = commentsManager.currentPost {
	                    CommentsNavigationHost(post: post) {
	                        commentsManager.dismissComments()
	                    }
	                    .environmentObject(commentsManager)
	                    .preferredColorScheme(preferredColorScheme)
	                    .transition(.move(edge: .trailing))
	                }
	            }
	        )
	        .overlay(
	            Group {
	                if let destination = mainOverlayDestination {
	                    LoopedMainOverlayNavigationHost(destination: destination) {
	                        withAnimation(.easeInOut(duration: 0.25)) {
	                            mainOverlayDestination = nil
	                        }
	                    }
	                    .preferredColorScheme(preferredColorScheme)
	                    .transition(.move(edge: .trailing))
	                }
	            }
	        )
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(
                feedViewModel: feedViewModel,
                onPostCreated: {
                    showCreatePost = false
                },
                onPostStatus: { message in
                    toastMessage = message
                }
            )
                .preferredColorScheme(preferredColorScheme)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(onChatSelected: { conversation, channel in
                // Dismiss the sheet first
                showNewMessage = false

                // Small delay to let sheet dismiss before showing chat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedConversation = conversation
                        selectedChannel = channel
                        showingChat = true
                    }
                }
            })
            .preferredColorScheme(preferredColorScheme)
        }
        .fullScreenCover(item: $menuDestination) { destination in
            switch destination {
            case .settings:
                SettingsModalHost()
                    .environmentObject(authViewModel)
                    .environmentObject(feedViewModel)
                    .environmentObject(commentsManager)
                    .environment(\.floatingActionButtonState, fabState)
                    .preferredColorScheme(preferredColorScheme)
            default:
                NavigationStack {
                    destinationView(for: destination)
                }
                .environmentObject(authViewModel)
                .environmentObject(feedViewModel)
                .environmentObject(commentsManager)
                .environment(\.floatingActionButtonState, fabState)
                .preferredColorScheme(preferredColorScheme)
            }
        }
        .sheet(isPresented: $showFAQSheet) {
            SafariView(url: faqUrl)
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $deepLinkProfile) { profile in
            NavigationStack {
                if profile.isAnonymous {
                    UserProfileView(anonProfileId: profile.profileId)
                } else {
                    UserProfileView(userId: profile.profileId)
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(feedViewModel)
            .environmentObject(commentsManager)
            .environment(\.floatingActionButtonState, fabState)
            .preferredColorScheme(preferredColorScheme)
        }
        .onOpenURL { url in
            #if canImport(FirebaseAuth)
            if Auth.auth().canHandle(url) {
                return
            }
            #endif
            handleDeepLink(url)
        }
    }

    private func mainLayout(for geometry: GeometryProxy) -> some View {
        let safeWidth = max(geometry.size.width, 0)
        let drawerWidth = safeWidth * 0.8

        return ZStack(alignment: .leading) {
            rightMenu(drawerWidth: drawerWidth)
            mainContent(drawerWidth: drawerWidth)
            floatingActionButton
            chatOverlay
        }
        .environmentObject(coachMarkPresenter)
        .overlayPreferenceValue(CoachMarkTargetKey.self) { targets in
            ZStack {
                feedDiscoveryOverlay(targets: targets)
                unverifiedSearchDiscoveryOverlay(targets: targets)
                presentedCoachMarkOverlay(targets: targets)
            }
        }
    }

    @ViewBuilder
    private func presentedCoachMarkOverlay(targets: [CoachMarkTarget: Anchor<CGRect>]) -> some View {
        if feedDiscoveryStep == nil,
           let overlay = coachMarkPresenter.overlay,
           targets[overlay.target] != nil {
            CoachMarkOverlay(
                target: overlay.target,
                targets: targets,
                message: overlay.message,
                primaryTitle: overlay.primaryTitle,
                secondaryTitle: overlay.secondaryTitle,
                onPrimary: overlay.onPrimary,
                onSecondary: overlay.onSecondary
            )
        }
    }

    @ViewBuilder
    private func rightMenu(drawerWidth: CGFloat) -> some View {
        if selectedTab == .home {
            HStack(spacing: 0) {
                Spacer()

                // Menu content constrained to 80% width with full background
                MenuContent(onMenuItemTap: { destination in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isRightMenuOpen = false
                    }
                    // Small delay to let drawer close before navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if destination == .faq {
                            showFAQSheet = true
                        } else {
                            menuDestination = destination
                        }
                    }
                })
                .frame(width: drawerWidth)
                .background(Color.loopedBackground.ignoresSafeArea(.all))
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.loopedBackground.ignoresSafeArea(.all))
            .offset(x: isRightMenuOpen ? 0 : drawerWidth)
            .allowsHitTesting(isRightMenuOpen)
        }
    }

    @ViewBuilder
		    private func mainContent(drawerWidth: CGFloat) -> some View {
		        tabContent
		            .frame(maxWidth: .infinity, maxHeight: .infinity)
		            .safeAreaInset(edge: .bottom, spacing: 0) {
		                if isTabBarVisible {
		                    CustomTabBar(
		                        selectedTab: $selectedTab,
		                        showsUpdateDot: { tab in shouldShowUpdateDot(for: tab) },
                                onReselect: handleTabReselect
	                    )
		                        .transition(.move(edge: .bottom).combined(with: .opacity))
	                }
	            }
	                .onPreferenceChange(LoopedTabBarHeightPreferenceKey.self) { newValue in
	                    if newValue > 0, abs(newValue - tabBarHeight) > 0.5 {
	                        tabBarHeight = newValue
	                    } else if newValue == 0 {
	                        tabBarHeight = 0
	                    }
	                }
	                .environment(\.loopedTabBarHeight, isTabBarVisible ? tabBarHeight : 0)
	                .environment(\.loopedPresentMainOverlay) { destination in
	                    withAnimation(.easeInOut(duration: 0.25)) {
	                        mainOverlayDestination = destination
	                    }
	                }
		            .animation(.easeInOut(duration: 0.25), value: isTabBarVisible)
	        .background(Color.loopedBackground.ignoresSafeArea())
	        .overlay(
            // Blocking overlay when drawer is open - prevents feed interactions
            Group {
                if selectedTab == .home && isRightMenuOpen {
                    Color.loopedClear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isRightMenuOpen = false
                            }
                        }
                        .allowsHitTesting(true)
                }
            }
        )
        .offset(x: selectedTab == .home ? (isRightMenuOpen ? -drawerWidth : 0) : 0)
        .scaleEffect((selectedTab == .home && isRightMenuOpen) ? 0.95 : 1.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRightMenuOpen)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack {
                FeedView(
                    isTabBarVisible: $isTabBarVisible,
                    scrollToTopSignal: $feedScrollToTopSignal,
                    onProfileTap: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isRightMenuOpen.toggle()
                        }
                    }
                )
                .environmentObject(feedViewModel)
                .environmentObject(commentsManager)
                .background(
                    NavigationPopToRootHandler(
                        popToRootSignal: $homePopToRootSignal,
                        lastProcessedSignal: $homePopToRootProcessedSignal,
                        didPopOnLastSignal: $homeDidPopOnReselect
                    )
                )
            }
        case .messages:
            NavigationStack {
                MessagesView(
                    viewModel: messagesViewModel,
                    onChatSelected: { conversation, channel in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedConversation = conversation
                            selectedChannel = channel
                            showingChat = true
                        }
                    }
                )
            }
        case .search:
            SearchView()
        case .notifications:
            NavigationStack {
                NotificationsView(viewModel: notificationsViewModel)
            }
        case .profile:
            NavigationStack {
                ProfileView()
            }
        }
    }

    private func handleTabReselect(_ tab: TabItem) {
        guard tab == .home else { return }

        if isRightMenuOpen {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isRightMenuOpen = false
            }
        }

        homePopToRootSignal += 1
    }

    private func shouldShowUpdateDot(for tab: TabItem) -> Bool {
        switch tab {
        case .messages:
            guard !isAnonymousMode else { return false }
            guard selectedTab != .messages else { return false }
            let lastSeen = Date(timeIntervalSince1970: lastSeenMessagesAt)
            let hasNewUnreadConversation = messagesViewModel.conversations.contains { conversation in
                conversation.hasUnreadMessages && conversation.lastMessageTimestamp > lastSeen
            }
            let hasPendingRequest = !messagesViewModel.messageRequests.isEmpty
            return hasNewUnreadConversation || hasPendingRequest
        case .notifications:
            guard selectedTab != .notifications else { return false }
            let lastSeen = Date(timeIntervalSince1970: lastSeenNotificationsAt)
            return notificationsViewModel.notifications.contains { notification in
                !notification.isRead && notification.createdAt > lastSeen
            }
        default:
            return false
        }
    }

    private func updateLastSeen(for tab: TabItem) {
        let now = Date().timeIntervalSince1970
        switch tab {
        case .messages:
            lastSeenMessagesAt = now
        case .notifications:
            lastSeenNotificationsAt = now
        default:
            break
        }
    }

    private func syncFloatingActionButtonVisibility() {
        switch selectedTab {
        case .home, .messages, .profile:
            fabState.isHidden = false
        default:
            fabState.isHidden = true
        }
    }

    @ViewBuilder
    private var floatingActionButton: some View {
        if (selectedTab == .home || selectedTab == .messages || selectedTab == .profile)
            && !commentsManager.isPresented
            && (selectedTab != .home || !isRightMenuOpen)
            && !fabState.isHidden {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Group {
                        if selectedTab == .messages {
                            FloatingActionButton(type: .sendMessage) {
                                showNewMessage = true
                            }
                        } else {
                            FloatingActionButton(type: .addPost) {
                                showCreatePost = true
                            }
                            .coachMarkTarget(.feedPostButton)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, isTabBarVisible ? 60 : 16)
                    .animation(.easeInOut(duration: 0.25), value: isTabBarVisible)
                }
            }
        }
    }

    @ViewBuilder
    private var chatOverlay: some View {
        if showingChat {
            ChatNavigationHost(
                conversation: selectedConversation,
                channel: selectedChannel,
                conversationId: deepLinkConversationId,
                channelId: deepLinkChannelId
            ) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingChat = false
                    selectedConversation = nil
                    selectedChannel = nil
                    deepLinkConversationId = nil
                    deepLinkChannelId = nil
                }
            }
            .transition(.move(edge: .trailing))
        }
    }

    @ViewBuilder
    private func feedDiscoveryOverlay(targets: [CoachMarkTarget: Anchor<CGRect>]) -> some View {
        if let step = feedDiscoveryStep,
           selectedTab == .home,
           !isRightMenuOpen,
           !commentsManager.isPresented,
           !showingChat,
           !fabState.isHidden,
           targets[step.target] != nil {
            CoachMarkOverlay(
                target: step.target,
                targets: targets,
                message: step.message,
                primaryTitle: step.primaryTitle,
                secondaryTitle: step.secondaryTitle,
                onPrimary: advanceFeedDiscovery,
                onSecondary: skipFeedDiscovery
            )
        }
    }

    @ViewBuilder
    private func unverifiedSearchDiscoveryOverlay(targets: [CoachMarkTarget: Anchor<CGRect>]) -> some View {
        if isShowingUnverifiedSearchDiscovery,
           selectedTab == .home,
           isTabBarVisible,
           !isRightMenuOpen,
           !commentsManager.isPresented,
           !showingChat,
           feedDiscoveryStep == nil,
           coachMarkPresenter.overlay == nil,
           targets[.mainTabSearch] != nil {
            CoachMarkOverlay(
                target: .mainTabSearch,
                targets: targets,
                message: "Search for the community you want to verify in. You can verify from the community page.",
                primaryTitle: "Got it",
                secondaryTitle: nil,
                onPrimary: dismissUnverifiedSearchDiscovery,
                onSecondary: nil
            )
        }
    }

    @ViewBuilder
    private func destinationView(for destination: MenuDestination) -> some View {
        MenuDestinationView(destination: destination)
    }
    
    private var preferredColorScheme: ColorScheme? {
        AppearanceMode.from(rawValue: appearanceMode).colorScheme
    }

    private func startFeedDiscoveryIfNeeded() {
        guard !didShowFeedDiscovery else { return }
        guard isVerifiedInAnyCommunity else { return }
        guard selectedTab == .home else { return }
        guard !isRightMenuOpen, !commentsManager.isPresented, !showingChat else { return }
        guard feedDiscoveryStep == nil else { return }
        guard !isShowingUnverifiedSearchDiscovery else { return }
        DispatchQueue.main.async {
            guard feedDiscoveryStep == nil else { return }
            feedDiscoveryStep = .postButton
        }
    }

    private func startUnverifiedSearchDiscoveryIfNeeded() {
        guard !isVerifiedInAnyCommunity else {
            isShowingUnverifiedSearchDiscovery = false
            return
        }
        guard !isShowingUnverifiedSearchDiscovery else { return }
        guard selectedTab == .home else { return }
        guard isTabBarVisible else { return }
        guard !isRightMenuOpen, !commentsManager.isPresented, !showingChat else { return }
        guard feedDiscoveryStep == nil else { return }
        guard coachMarkPresenter.overlay == nil else { return }
        guard !didEvaluateUnverifiedSearchDiscoveryThisSession else { return }

        let now = Date().timeIntervalSince1970
        let minInterval: TimeInterval = 18 * 60 * 60
        if unverifiedSearchDiscoveryLastShownAt > 0,
           now - unverifiedSearchDiscoveryLastShownAt < minInterval {
            return
        }

        didEvaluateUnverifiedSearchDiscoveryThisSession = true
        unverifiedSearchDiscoveryParity += 1
        guard unverifiedSearchDiscoveryParity % 2 == 1 else { return }

        unverifiedSearchDiscoveryLastShownAt = now
        isShowingUnverifiedSearchDiscovery = true
    }

    private func dismissUnverifiedSearchDiscovery() {
        isShowingUnverifiedSearchDiscovery = false
    }

    private func advanceFeedDiscovery() {
        guard let step = feedDiscoveryStep else { return }
        if let next = FeedDiscoveryStep(rawValue: step.rawValue + 1) {
            feedDiscoveryStep = next
        } else {
            didShowFeedDiscovery = true
            feedDiscoveryStep = nil
        }
    }

    private func skipFeedDiscovery() {
        didShowFeedDiscovery = true
        feedDiscoveryStep = nil
    }

    private var isVerifiedInAnyCommunity: Bool {
        feedViewModel.followedCommunities.contains(where: { $0.canPost })
    }

    private func handleDeepLink(_ url: URL) {
        guard let destination = parseDeepLink(url) else { return }
        switch destination {
        case .post(let postId):
            Task { await openPost(postId: postId, focusCommentId: nil) }
        case .comment(let commentId, let postId):
            if let postId {
                Task { await openPost(postId: postId, focusCommentId: commentId) }
            } else {
                selectedTab = .notifications
            }
        case .user(let userId, let isAnonymous):
            deepLinkProfile = DeepLinkProfile(profileId: userId, isAnonymous: isAnonymous)
        case .announcement:
            selectedTab = .notifications
        case .conversation(let conversationId):
            openChat(conversationId: conversationId, channelId: nil)
        case .channel(let channelId):
            openChat(conversationId: nil, channelId: channelId)
        }
    }

    private func openChat(conversationId: Int?, channelId: Int?) {
        selectedTab = .messages
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedConversation = nil
            selectedChannel = nil
            deepLinkConversationId = conversationId
            deepLinkChannelId = channelId
            showingChat = true
        }
    }

    private func openPost(postId: Int, focusCommentId: Int?) async {
        do {
            let post = try await deepLinkFeedService.fetchPost(postId: postId)
            await MainActor.run {
                selectedTab = .home
                commentsManager.showComments(for: post, focusCommentId: focusCommentId)
            }
        } catch {
            await MainActor.run {
                toastMessage = ToastMessage(text: "Post unavailable", kind: .error)
            }
        }
    }

    private func parseDeepLink(_ url: URL) -> DeepLinkDestination? {
        guard url.scheme == "looped" else { return nil }
        let host = (url.host ?? "").lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let idValue = pathComponents.first.flatMap { Int($0) }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let postId = components?.queryItems?.first(where: { $0.name == "post_id" })?.value.flatMap(Int.init)
        let isAnonymous = components?.queryItems?.first(where: { $0.name == "anon" })?.value == "true"

        switch host {
        case "post":
            if let idValue { return .post(idValue) }
        case "comment":
            if let idValue { return .comment(idValue, postId: postId) }
        case "user":
            if let idValue { return .user(idValue, isAnonymous: isAnonymous) }
        case "announcement":
            if idValue != nil { return .announcement }
        case "conversations":
            if let idValue { return .conversation(idValue) }
        case "channels":
            if let idValue { return .channel(idValue) }
        default:
            break
        }
        return nil
    }

    private struct DeepLinkProfile: Identifiable {
        let profileId: Int
        let isAnonymous: Bool

        var id: String {
            "\(profileId)-\(isAnonymous ? "anon" : "user")"
        }
    }

    private enum DeepLinkDestination {
        case post(Int)
        case comment(Int, postId: Int?)
        case user(Int, isAnonymous: Bool)
        case announcement
        case conversation(Int)
        case channel(Int)
    }

    private enum FeedDiscoveryStep: Int, CaseIterable {
        case postButton
        case filters

        var target: CoachMarkTarget {
            switch self {
            case .postButton:
                return .feedPostButton
            case .filters:
                return .feedFilterPills
            }
        }

        var message: String {
            switch self {
            case .postButton:
                return "Post here once you're verified in a community. You can still read every post."
            case .filters:
                return "Filter the feed by the communities you follow."
            }
        }

        var primaryTitle: String {
            switch self {
            case .postButton:
                return "Next"
            case .filters:
                return "Got it"
            }
        }

        var secondaryTitle: String? {
            switch self {
            case .postButton:
                return "Skip"
            case .filters:
                return nil
            }
        }
    }
}

#Preview {
    ContentView()
}
